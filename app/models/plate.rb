class Plate < ApplicationRecord
    has_many :wells, dependent: :destroy
    has_many :plate_locations, dependent: :destroy
    has_many :locations, through: :plate_locations

    validates :barcode, uniqueness: true
    before_validation :generate_barcode_if_blank
    after_create :create_wells_from_attributes

    attr_accessor :plate_rows, :plate_columns, :plate_subwells_per_well

    # Scope to get plates that are currently at any location
    scope :with_current_location, -> {
      joins(:plate_locations).merge(PlateLocation.most_recent_for_each_plate)
    }

    # Scope to get plates currently at a specific location
    scope :currently_at_location, ->(location) {
      with_current_location.where(plate_locations: { location_id: location.id })
    }

    def current_location
        plate_locations.recent_first.first&.location
    end

    def current_location_record
        plate_locations.recent_first.first
    end

    def location_history
        plate_locations.recent_first.includes(:location)
    end

    def move_to_location!(location)
        # Check if location is already occupied by another plate
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

        plate_locations.create!(
            location: location,
            moved_at: Time.current
        )
    end

    def rows
        wells.maximum(:well_row) || 8
    end

    def columns
        wells.maximum(:well_column) || 12
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

    def create_wells_from_attributes
        rows = plate_rows&.to_i || 8
        columns = plate_columns&.to_i || 12
        subwells = plate_subwells_per_well&.to_i || 1

        create_wells!(rows: rows, columns: columns, subwells_per_well: subwells)
    end
end
