class CreatePrototypeWells < ActiveRecord::Migration[8.0]
  def change
    create_table :prototype_wells do |t|
      t.references :plate_prototype, null: false, foreign_key: true
      t.integer :well_row
      t.integer :well_column
      t.integer :subwell
      t.decimal :x_mm
      t.decimal :y_mm
      t.decimal :z_mm

      t.timestamps
    end
  end
end
