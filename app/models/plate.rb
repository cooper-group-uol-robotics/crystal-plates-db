class Plate < ApplicationRecord
    has_many :wells, dependent: :destroy

    validates :barcode, presence: true, uniqueness: true
    validates :location_position, inclusion: 1..10
    validates :location_stack, inclusion: 1..20
    after_create :create_wells!

    def rows
        wells.maximum(:well_row) || 8
    end

    def columns
        wells.maximum(:well_column) || 12
    end

    private

    def create_wells!
        wells_to_create = []
        (1..8).each do |row|          # rows 1 to 8
        (1..12).each do |column|    # columns 1 to 12
            wells_to_create << wells.build(well_row: row, well_column: column)
        end
        end
        # Use insert_all or save all wells at once:
        Well.import wells_to_create   # bulk insert with activerecord-import gem, or:

        # If you don't want an extra gem, just:
        # wells_to_create.each(&:save!)
    end
    
end
