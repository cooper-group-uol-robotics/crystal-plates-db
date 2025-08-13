class Plate < ApplicationRecord
    acts_as_paranoid

    has_many :wells
    has_many :point_of_interests, through: :wells
    has_many :plate_locations
    has_many :locations, through: :plate_locations

    validates :barcode, uniqueness: true
    validates :name, length: { maximum: 255 }, allow_blank: true
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
    def self.with_current_location_data
      # Get the latest plate_location for each plate
      latest_plate_location_ids = PlateLocation
        .select("MAX(id) as latest_id")
        .group(:plate_id)

      current_locations = PlateLocation
        .joins("INNER JOIN (#{latest_plate_location_ids.to_sql}) latest ON plate_locations.id = latest.latest_id")
        .left_joins(:location)
        .select('plate_locations.plate_id, locations.id as location_id, locations.name as location_name, 
                 locations.carousel_position, locations.hotel_position')

      query = self
        .joins("LEFT JOIN (#{current_locations.to_sql}) current_locations ON plates.id = current_locations.plate_id")
        .select('plates.*, current_locations.location_id as current_location_id, 
                 current_locations.location_name as current_location_name,
                 current_locations.carousel_position as current_location_carousel_position,
                 current_locations.hotel_position as current_location_hotel_position')

      query.map do |plate|
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
        plate
      end
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
end
