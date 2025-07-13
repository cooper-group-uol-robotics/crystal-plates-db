class AddUniquenessConstraintsToLocations < ActiveRecord::Migration[8.0]
  def change
    # Add unique index for carousel and hotel position combination
    add_index :locations, [ :carousel_position, :hotel_position ],
              unique: true,
              name: 'index_locations_on_carousel_and_hotel_positions',
              where: 'carousel_position IS NOT NULL AND hotel_position IS NOT NULL'

    # Add unique index for special location names (only when carousel/hotel positions are NULL)
    add_index :locations, :name,
              unique: true,
              name: 'index_locations_on_name',
              where: 'name IS NOT NULL AND carousel_position IS NULL AND hotel_position IS NULL'
  end
end
