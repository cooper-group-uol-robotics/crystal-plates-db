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
    # Return empirical formula if available from SciFormation
    return empirical_formula if empirical_formula.present?
    
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
    if association(:well_contents).loaded?
      well_contents.any?
    else
      well_contents.exists?
    end
  end

  # Check if chemical is used in stock solutions
  def used_in_stock_solutions?
    if association(:stock_solution_components).loaded?
      stock_solution_components.any?
    else
      stock_solution_components.exists?
    end
  end

  # Check if chemical can be deleted (not used anywhere)
  def can_be_deleted?
    !used_in_wells? && !used_in_stock_solutions?
  end

  # Get wells where this chemical is used directly
  def direct_wells_count
    if association(:well_contents).loaded?
      well_contents.size
    else
      well_contents.count
    end
  end

  # Get usage summary
  def usage_summary
    summaries = []

    if used_in_wells?
      summaries << "#{direct_wells_count} well#{direct_wells_count == 1 ? '' : 's'} (direct)"
    end

    if used_in_stock_solutions?
      stock_solution_count = if association(:stock_solutions).loaded?
                              stock_solutions.size
                            else
                              stock_solutions.count
                            end
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
  def self.fetch_from_sciformation(department_id: "124", cookie: nil, barcode: nil)
    require "net/http"
    require "uri"
    require "json"

    # Use cookie from settings if not provided
    cookie ||= Setting.sciformation_cookie

    # Check if cookie is available
    if cookie.blank?
      Rails.logger.error "Sciformation cookie not configured. Please set it in the settings."
      return { success: false, error: "Sciformation cookie not configured. Please set it in the settings." }
    end

    uri = URI("https://jfb.liverpool.ac.uk/performSearch")

    # Prepare the request
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60  # 60 second timeout
    http.open_timeout = 30  # 30 second connection timeout

    Rails.logger.info "HTTP timeout settings - read: #{http.read_timeout}s, open: #{http.open_timeout}s"

    request = Net::HTTP::Post.new(uri)
    request["Cookie"] = "SCIFORMATION=#{cookie}"

    # Set form data based on whether barcode is provided
    if barcode.present?
      # Search for specific barcode
      form_data = {
        "table" => "CdbContainer",
        "format" => "json",
        "query" => "[0]",
        "crit0" => "barcode",
        "val0" => barcode
      }
      Rails.logger.info "Form data for barcode search: #{form_data.inspect}"
      request.set_form_data(form_data)
    else
      # Search all containers in department
      form_data = {
        "table" => "CdbContainer",
        "format" => "json",
        "query" => "[0]",
        "crit0" => "department",
        "val0" => department_id
      }
      Rails.logger.info "Form data for full department search: #{form_data.inspect}"
      request.set_form_data(form_data)
    end

    if barcode.present?
      Rails.logger.info "Fetching chemical data from Sciformation for barcode '#{barcode}' in department #{department_id}..."
    else
      Rails.logger.info "Fetching all chemical data from Sciformation for department #{department_id}..."
    end

    begin
      Rails.logger.info "Making HTTP request to Sciformation..."
      response = http.request(request)
      Rails.logger.info "Received response from Sciformation with status: #{response.code}"

      if response.code.to_i == 200
        Rails.logger.info "Response body size: #{response.body.length} characters"
        Rails.logger.debug "Response body preview: #{response.body[0, 500]}..." if response.body.length > 500

        Rails.logger.info "Parsing JSON response..."
        data = JSON.parse(response.body)
        Rails.logger.info "Parsed JSON successfully. Data is an array: #{data.is_a?(Array)}, size: #{data.is_a?(Array) ? data.size : 'N/A'}"

        Rails.logger.info "Starting data import..."
        import_results = import_sciformation_data(data)

        Rails.logger.info "Sciformation import completed: #{import_results}"
        import_results
      else
        Rails.logger.error "Failed to fetch data from Sciformation: HTTP #{response.code}"
        Rails.logger.error "Response body: #{response.body}" if response.body
        { success: false, error: "HTTP #{response.code}" }
      end

    rescue JSON::ParserError => e
      Rails.logger.error "JSON parsing error: #{e.message}"
      Rails.logger.error "Response body that failed to parse: #{response.body}" if defined?(response)
      { success: false, error: "Invalid JSON response from Sciformation" }
    rescue Net::TimeoutError => e
      Rails.logger.error "Timeout error communicating with Sciformation: #{e.message}"
      { success: false, error: "Request timeout - Sciformation may be slow or unavailable" }
    rescue => e
      Rails.logger.error "Error fetching from Sciformation: #{e.message}"
      Rails.logger.error "Backtrace: #{e.backtrace.join("\n")}"
      { success: false, error: e.message }
    end
  end

  private

  # Private class method to handle the actual data import
  def self.import_sciformation_data(data)
    Rails.logger.info "Starting import_sciformation_data with data type: #{data.class}, size: #{data.is_a?(Array) ? data.size : 'N/A'}"
    return { success: false, error: "No data provided" } unless data.is_a?(Array)

    imported_count = 0
    updated_count = 0
    skipped_count = 0
    errors = []

    Rails.logger.info "Processing #{data.size} records from Sciformation..."

    data.each_with_index do |item, index|
      Rails.logger.debug "Processing record #{index + 1}/#{data.size}..." if index % 10 == 0 || data.size < 10
      begin
        sciformation_id = item["pk"]
        name = item.dig("moleculeNames", "name")
        smiles = item["smiles"]
        cas = item["casNr"]
        amount = item["realAmount"]
        storage = item["storageName"]
        barcode = item["barcode"]
        empirical_formula = item["empFormula"]

        # Skip if essential data is missing
        if sciformation_id.blank? || name.blank?
          Rails.logger.warn "Skipping record #{index + 1}: Missing essential data (pk=#{sciformation_id}, name=#{name})"
          skipped_count += 1
          next
        end

        # Skip chemicals with unwanted storage locations
        if storage.blank? || storage.strip.downcase.in?([ "*missing*", "*waste*" ])
          Rails.logger.warn "Skipping record #{index + 1}: Unwanted storage location (pk=#{sciformation_id}, storage=#{storage})"
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
            barcode: barcode,
            empirical_formula: empirical_formula
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
            barcode: barcode,
            empirical_formula: empirical_formula
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

    Rails.logger.info "Data import processing complete. Imported: #{imported_count}, Updated: #{updated_count}, Skipped: #{skipped_count}, Errors: #{errors.size}"

    result = {
      success: true,
      imported: imported_count,
      updated: updated_count,
      skipped: skipped_count,
      errors: errors,
      total_records: data.length,
      total_chemicals: Chemical.count
    }

    Rails.logger.info "Returning import result: #{result.inspect}"
    result
  end
end
