class AllowNullLocationInPlateLocations < ActiveRecord::Migration[8.0]
  def change
    # Allow location_id to be null to support unassigned plates
    change_column_null :plate_locations, :location_id, true

    # Remove the foreign key constraint temporarily
    remove_foreign_key :plate_locations, :locations

    # Add it back but allow null values
    add_foreign_key :plate_locations, :locations, validate: false
  end
end
