class RemoveMovedByFromPlateLocations < ActiveRecord::Migration[8.0]
  def change
    remove_column :plate_locations, :moved_by, :string
  end
end
