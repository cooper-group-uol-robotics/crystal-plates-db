require "cgi"

class Chemical < ApplicationRecord
  has_many :stock_solution_components, dependent: :destroy
  has_many :stock_solutions, through: :stock_solution_components

  # Direct associations with wells through polymorphic well_contents
  has_many :well_contents, as: :contentable, dependent: :destroy
  has_many :wells, through: :well_contents

  validates :sciformation_id, presence: true, uniqueness: true
  validates :name, presence: true
  validates :smiles, presence: true

  scope :by_name, ->(name) { where("name LIKE ?", "%#{name}%") }
  scope :by_cas, ->(cas) { where(cas: cas) }

  def to_s
    name.presence || "Chemical ##{id}"
  end

  def molecular_formula
    # This could be calculated from SMILES if needed
    # For now, return nil until we add that functionality
    nil
  end

  def short_storage
    return nil unless storage.present?

    storage_parts = storage.split("/").map(&:strip)
    storage_parts.last(2).join(" / ")
  end

  def full_storage_path?
    return false unless storage.present?

    storage.split("/").length > 2
  end

  def has_structure?
    smiles.present? && smiles.strip != ""
  end

  # Check if chemical is used directly in wells
  def used_in_wells?
    well_contents.exists?
  end

  # Check if chemical is used in stock solutions
  def used_in_stock_solutions?
    stock_solution_components.exists?
  end

  # Check if chemical can be deleted (not used anywhere)
  def can_be_deleted?
    !used_in_wells? && !used_in_stock_solutions?
  end

  # Get wells where this chemical is used directly
  def direct_wells_count
    well_contents.count
  end

  # Get usage summary
  def usage_summary
    summaries = []

    if used_in_wells?
      summaries << "#{direct_wells_count} well#{direct_wells_count == 1 ? '' : 's'} (direct)"
    end

    if used_in_stock_solutions?
      stock_solution_count = stock_solutions.count
      summaries << "#{stock_solution_count} stock solution#{stock_solution_count == 1 ? '' : 's'}"
    end

    return "Not used" if summaries.empty?
    summaries.join(", ")
  end

  def structure_image_url(width: 200, height: 200)
    return nil unless has_structure?

    # Use the PubChem structure service - more reliable
    encoded_smiles = CGI.escape(smiles)
    "https://pubchem.ncbi.nlm.nih.gov/rest/pug/compound/smiles/#{encoded_smiles}/PNG?image_size=#{width}x#{height}"
  end

  # Class method to fetch and import data from Sciformation
  def self.fetch_from_sciformation(department_id: "124", cookie: "f8afbe9ee73920eac572ed78f0b4")
    require "net/http"
    require "uri"
    require "json"

    # Default cookie - you should pass the current one as a parameter

    uri = URI("https://sciformation.liverpool.ac.uk/performSearch")

    # Prepare the request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Cookie"] = "SCIFORMATION=#{cookie}"

    # Set form data
    request.set_form_data({
      "table" => "CdbContainer",
      "format" => "json",
      "query" => "[0]",
      "crit0" => "department",
      "op0" => "OP_IN_NUM",
      "val0" => department_id
    })

    Rails.logger.info "Fetching chemical data from Sciformation for department #{department_id}..."

    begin
      response = http.request(request)

      if response.code.to_i == 200
        data = JSON.parse(response.body)
        import_results = import_sciformation_data(data)

        Rails.logger.info "Sciformation import completed: #{import_results}"
        import_results
      else
        Rails.logger.error "Failed to fetch data from Sciformation: HTTP #{response.code}"
        { success: false, error: "HTTP #{response.code}" }
      end

    rescue => e
      Rails.logger.error "Error fetching from Sciformation: #{e.message}"
      { success: false, error: e.message }
    end
  end

  private

  # Private class method to handle the actual data import
  def self.import_sciformation_data(data)
    return { success: false, error: "No data provided" } unless data.is_a?(Array)

    imported_count = 0
    updated_count = 0
    skipped_count = 0
    errors = []

    data.each_with_index do |item, index|
      begin
        sciformation_id = item["pk"]
        name = item.dig("moleculeNames", "name")
        smiles = item["smiles"]
        cas = item["casNr"]
        amount = item["realAmount"]
        storage = item["storageName"]
        barcode = item["barcode"]

        # Skip if essential data is missing
        if sciformation_id.blank? || name.blank? || smiles.blank?
          Rails.logger.warn "Skipping record #{index + 1}: Missing essential data (pk=#{sciformation_id}, name=#{name})"
          skipped_count += 1
          next
        end

        # Check if chemical already exists
        existing = Chemical.find_by(sciformation_id: sciformation_id)

        if existing
          # Update existing record
          existing.update!(
            name: name,
            smiles: smiles,
            cas: cas,
            amount: amount,
            storage: storage,
            barcode: barcode
          )
          Rails.logger.info "Updated chemical #{sciformation_id}: #{name}"
          updated_count += 1
        else
          # Create new record
          Chemical.create!(
            sciformation_id: sciformation_id,
            name: name,
            smiles: smiles,
            cas: cas,
            amount: amount,
            storage: storage,
            barcode: barcode
          )
          Rails.logger.info "Created chemical #{sciformation_id}: #{name}"
          imported_count += 1
        end

      rescue => e
        error_msg = "Error processing record #{index + 1} (pk=#{item['pk']}): #{e.message}"
        Rails.logger.error error_msg
        errors << error_msg
      end
    end

    {
      success: true,
      imported: imported_count,
      updated: updated_count,
      skipped: skipped_count,
      errors: errors,
      total_records: data.length,
      total_chemicals: Chemical.count
    }
  end
end
