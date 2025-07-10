class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.integer :carousel_position
      t.integer :hotel_position
      t.string :name

      t.timestamps
    end
  end
end
