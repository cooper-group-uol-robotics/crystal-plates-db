class CreatePlateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :plate_locations do |t|
      t.references :plate, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.datetime :moved_at
      t.string :moved_by

      t.timestamps
    end
  end
end
