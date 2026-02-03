class Plate < ApplicationRecord
    acts_as_paranoid

    has_many :wells
    has_many :point_of_interests, through: :wells
    has_many :plate_locations
    has_many :locations, through: :plate_locations
    has_many :calorimetry_experiments, dependent: :destroy
    has_many :well_scores, through: :wells

    validates :barcode, uniqueness: true
    validates :name, length: { maximum: 255 }, allow_blank: true
    validates :coshh_form_code, format: { 
      with: /\A[A-Za-z0-9\_]+-\d+\z/, 
      message: "must be in format like 'TFE-045' (alphanumeric, hyphen, number)" 
    }, allow_blank: true
    
    before_validation :generate_barcode_if_blank
    after_create :create_wells_from_prototype_or_attributes

    attr_accessor :plate_rows, :plate_columns, :plate_subwells_per_well

    # Scope to get plates that are currently at any location
    scope :with_current_location, -> {
      joins(:plate_locations).merge(PlateLocation.most_recent_for_each_plate)
    }

    # Scope to get plates currently at a specific location
    scope :currently_at_location, ->(location) {
      with_current_location.where(plate_locations: { location_id: location.id })
    }

    # Scope to get plates that are currently unassigned
    scope :unassigned, -> {
      # Get latest plate location for each plate where location_id is NULL
      latest_location_ids = PlateLocation
        .select("MAX(id)")
        .group(:plate_id)

      unassigned_plate_ids = PlateLocation
        .where(location_id: nil)
        .where("id IN (#{latest_location_ids.to_sql})")
        .pluck(:plate_id)

      where(id: unassigned_plate_ids)
    }

    # Scope to get plates that are currently assigned to any location
    scope :assigned, -> {
      # Get plates that don't have unassigned as their latest location
      where.not(id: unassigned.pluck(:id))
    }

    # Efficiently bulk load current location data for plates to avoid N+1 queries
    scope :with_current_location_data, -> {
      # Get the latest plate_location for each plate
      latest_plate_location_ids = PlateLocation
        .select("MAX(id) as latest_id")
        .group(:plate_id)

      current_locations = PlateLocation
        .joins("INNER JOIN (#{latest_plate_location_ids.to_sql}) latest ON plate_locations.id = latest.latest_id")
        .left_joins(:location)
        .select('plate_locations.plate_id, locations.id as location_id, locations.name as location_name,
                 locations.carousel_position, locations.hotel_position')

      joins("LEFT JOIN (#{current_locations.to_sql}) current_locations ON plates.id = current_locations.plate_id")
        .select('plates.*, current_locations.location_id as current_location_id,
                 current_locations.location_name as current_location_name,
                 current_locations.carousel_position as current_location_carousel_position,
                 current_locations.hotel_position as current_location_hotel_position')
    }

    # Process plates with cached location data after they've been loaded
    def self.cache_current_location_data(plates)
      plates.each do |plate|
        # Cache the current location data to avoid N+1 queries
        if plate.try(:current_location_id)
          current_location = Location.new(
            id: plate.current_location_id,
            name: plate.current_location_name,
            carousel_position: plate.current_location_carousel_position,
            hotel_position: plate.current_location_hotel_position
          )
          # Cache the location to avoid future queries
          plate.define_singleton_method(:current_location) { current_location }
        else
          # Cache nil to avoid future queries for unassigned plates
          plate.define_singleton_method(:current_location) { nil }
        end
      end
      plates
    end

    def really_destroy!
        wells.each(&:destroy!)
        plate_locations.each(&:destroy!)
        super
    end

    def current_location
        plate_locations.recent_first.first&.location
    end

    def current_location_record
        plate_locations.recent_first.first
    end

    def display_name
        if name.present?
            "#{barcode} (#{name})"
        else
            barcode
        end
    end

    def location_history
        plate_locations.recent_first.includes(:location)
    end

    def assigned?
        current_location.present?
    end

    def unassigned?
        !assigned?
    end

    def move_to_location!(location)
        # Check if location is already occupied by another plate (only if location is not nil)
        if location.present?
          # Find plates whose most recent location (anywhere) is this location
          latest_locations_subquery = PlateLocation
            .select("plate_id, MAX(id) as latest_id")
            .group(:plate_id)

          occupied_by = PlateLocation.joins(:plate)
                                    .joins("INNER JOIN (#{latest_locations_subquery.to_sql}) latest ON plate_locations.plate_id = latest.plate_id AND plate_locations.id = latest.latest_id")
                                    .where(location: location)
                                    .where.not(plate_id: self.id)
                                    .includes(:plate)
                                    .first

          if occupied_by
              errors.add(:base, "Location #{location.display_name} is already occupied by plate #{occupied_by.plate.barcode}")
              raise ActiveRecord::RecordInvalid, self
          end
        end

        plate_locations.create!(
            location: location,
            moved_at: Time.current
        )
    end

    def unassign_location!
        move_to_location!(nil)
    end

    def rows
        wells.maximum(:well_row) || 8
    end

    def columns
        wells.maximum(:well_column) || 12
    end

    def subwells_per_well
        wells.maximum(:subwell) || 1
    end

    # Find a well by human-readable identifier (e.g., "A1", "H12", "B2_3" for B2 subwell 3)
    def find_well_by_identifier(well_string)
        parsed = self.class.parse_well_identifier(well_string)
        return nil unless parsed

        wells.find_by(
            well_row: parsed[:row],
            well_column: parsed[:column],
            subwell: parsed[:subwell]
        )
    end

    # Parse human-readable well identifiers
    # Supports formats: A1, B12, H5_2 (H5 subwell 2), C3_10 (C3 subwell 10)
    def self.parse_well_identifier(well_string)
        return nil if well_string.blank?

        # Remove spaces and convert to uppercase
        clean_string = well_string.strip.upcase

        # Match patterns like A1, H12, B2_3
        match = clean_string.match(/^([A-Z])(\d+)(?:_(\d+))?$/)
        return nil unless match

        row_letter = match[1]
        column_str = match[2]
        subwell_str = match[3] || "1"

        # Convert letter to number (A=1, B=2, etc.)
        row_number = row_letter.ord - "A".ord + 1

        # Parse column and subwell
        column = column_str.to_i
        subwell = subwell_str.to_i

        # Basic validation
        return nil if row_number < 1 || column < 1 || subwell < 1

        {
            row: row_number,
            column: column,
            subwell: subwell
        }
    end

    private

    def generate_barcode_if_blank
        return if barcode.present?

        # Generate a unique barcode
        loop do
            candidate_barcode = "#{Random.rand(60000000..69999999)}"

            # Check if this barcode already exists
            unless Plate.exists?(barcode: candidate_barcode)
                self.barcode = candidate_barcode
                break
            end
        end
    end

    def create_wells!(rows: 8, columns: 12, subwells_per_well: 1)
        wells_to_create = []
        (1..rows).each do |row|
            (1..columns).each do |column|
                (1..subwells_per_well).each do |subwell|
                    wells_to_create << {
                        plate_id: id,
                        well_row: row,
                        well_column: column,
                        subwell: subwell
                    }
                end
            end
        end
        # Use insert_all for bulk insert
        Well.insert_all(wells_to_create)
    end

    def create_wells_from_prototype!(prototype)
        wells_to_create = prototype.prototype_wells.map do |pw|
            {
                plate_id: id,
                well_row: pw.well_row,
                well_column: pw.well_column,
                subwell: pw.subwell,
                x_mm: pw.x_mm,
                y_mm: pw.y_mm,
                z_mm: pw.z_mm
            }
        end
        Well.insert_all(wells_to_create) if wells_to_create.any?
    end

    def create_wells_from_prototype_or_attributes
        if plate_prototype_id.present?
            prototype = PlatePrototype.find_by(id: plate_prototype_id)
            if prototype
                create_wells_from_prototype!(prototype)
                return
            end
        end
        create_wells_from_attributes
    end

    def create_wells_from_attributes
        rows = plate_rows&.to_i || 8
        columns = plate_columns&.to_i || 12
        subwells = plate_subwells_per_well&.to_i || 1

        create_wells!(rows: rows, columns: columns, subwells_per_well: subwells)
    end

    public

    # COSHH form methods
    def coshh_form_prefix
      return nil unless coshh_form_code.present?
      coshh_form_code.match(/\A([A-Za-z0-9\_]+)-\d+\z/)&.captures&.first
    end

    def coshh_form_number
      return nil unless coshh_form_code.present?
      match = coshh_form_code.match(/\A[A-Za-z0-9\_]+-(\d+)\z/)
      match ? match.captures.first.to_i : nil
    end

    # Fetch allowed chemical Sciformation IDs from COSHH form
    def fetch_coshh_chemical_ids
      return [] unless coshh_form_code.present?

      begin
        service = SciformationService.new
        service.fetch_coshh_chemicals(coshh_form_code)
      rescue SciformationService::AuthenticationError, SciformationService::QueryError => e
        Rails.logger.error "Failed to fetch COSHH chemical IDs: #{e.message}"
        []
      end
    end

    # Get list of chemicals from database that are allowed by COSHH form
    def allowed_chemicals
      return Chemical.none unless coshh_form_code.present?

      sciformation_ids = fetch_coshh_chemical_ids
      return Chemical.none if sciformation_ids.empty?

      Chemical.where(sciformation_id: sciformation_ids)
    end

    # Get list of stock solutions that only contain allowed chemicals
    def allowed_stock_solutions
      return StockSolution.none unless coshh_form_code.present?

      allowed_chems = allowed_chemicals.to_a
      return StockSolution.none if allowed_chems.empty?

      # Find stock solutions where all component chemicals are allowed
      StockSolution.all.select do |stock_solution|
        stock_solution.chemicals.all? do |chemical|
          chemical_allowed_by_coshh?(chemical, allowed_chems)
        end
      end
    end

    # Get all chemicals currently used in this plate's wells
    def chemicals_used
      Chemical.joins(well_contents: :well)
              .where(wells: { plate_id: id })
              .distinct
    end

    # Get all stock solutions currently used in this plate's wells
    def stock_solutions_used
      StockSolution.joins(well_contents: :well)
                   .where(wells: { plate_id: id })
                   .distinct
    end

    # Check if all chemicals in wells are compliant with COSHH form
    def coshh_compliant?
      return true unless coshh_form_code.present?

      allowed_chems = allowed_chemicals.to_a
      
      # If no allowed chemicals were found, the plate is only compliant if it has no chemicals
      if allowed_chems.empty?
        return chemicals_used.empty? && stock_solutions_used.empty?
      end

      # Check direct chemicals
      non_compliant_chemicals = chemicals_used.reject do |chemical|
        chemical_allowed_by_coshh?(chemical, allowed_chems)
      end

      # Check chemicals in stock solutions
      non_compliant_from_stock = stock_solutions_used.flat_map do |stock_solution|
        stock_solution.chemicals.reject do |chemical|
          chemical_allowed_by_coshh?(chemical, allowed_chems)
        end
      end.uniq

      non_compliant_chemicals.empty? && non_compliant_from_stock.empty?
    end

    # Get list of non-compliant chemicals for display
    def coshh_non_compliant_chemicals
      return [] unless coshh_form_code.present?

      allowed_chems = allowed_chemicals.to_a
      
      # If no allowed chemicals were found, all chemicals in the plate are non-compliant
      if allowed_chems.empty?
        direct = chemicals_used.to_a
        from_stock = stock_solutions_used.flat_map(&:chemicals).uniq
        return (direct + from_stock).uniq
      end

      # Check direct chemicals
      non_compliant_direct = chemicals_used.reject do |chemical|
        chemical_allowed_by_coshh?(chemical, allowed_chems)
      end

      # Check chemicals in stock solutions
      non_compliant_from_stock = stock_solutions_used.flat_map do |stock_solution|
        stock_solution.chemicals.reject do |chemical|
          chemical_allowed_by_coshh?(chemical, allowed_chems)
        end
      end.uniq

      (non_compliant_direct + non_compliant_from_stock).uniq
    end

    private

    # Check if a chemical is allowed by COSHH form
    # Matches on Sciformation ID first, then falls back to CAS number
    def chemical_allowed_by_coshh?(chemical, allowed_chemicals)
      # Match by Sciformation ID
      return true if allowed_chemicals.any? { |ac| ac.sciformation_id == chemical.sciformation_id }

      # Fall back to CAS number matching (only if CAS is present)
      if chemical.cas.present?
        return true if allowed_chemicals.any? { |ac| ac.cas.present? && ac.cas == chemical.cas }
      end

      false
    end

    # Validation method for COSHH compliance
    def validate_well_chemicals_against_coshh
      return if wells.empty? || coshh_form_code.blank?

      allowed_chems = allowed_chemicals.to_a
      return if allowed_chems.empty?  # Skip validation if can't fetch from Sciformation

      # Check direct chemicals
      non_compliant_chemicals = chemicals_used.reject do |chemical|
        chemical_allowed_by_coshh?(chemical, allowed_chems)
      end

      # Check chemicals in stock solutions
      non_compliant_from_stock = stock_solutions_used.flat_map do |stock_solution|
        stock_solution.chemicals.reject do |chemical|
          chemical_allowed_by_coshh?(chemical, allowed_chems)
        end
      end.uniq

      all_non_compliant = (non_compliant_chemicals + non_compliant_from_stock).uniq

      if all_non_compliant.any?
        chemical_list = all_non_compliant.map(&:name).join(", ")
        errors.add(:coshh_form_code, 
          "does not include the following chemicals used in this plate: #{chemical_list}")
      end
    end
end
