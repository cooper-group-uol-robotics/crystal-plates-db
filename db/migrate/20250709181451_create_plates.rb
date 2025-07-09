class CreatePlates < ActiveRecord::Migration[8.0]
  def change
    create_table :plates do |t|
      t.string :barcode
      t.integer :location_position
      t.integer :location_stack

      t.timestamps
    end
    add_index :plates, :barcode, unique: true
  end
end
