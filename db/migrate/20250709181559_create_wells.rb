class CreateWells < ActiveRecord::Migration[8.0]
  def change
    create_table :wells do |t|
      t.references :plate, null: false, foreign_key: true
      t.integer :well_row
      t.integer :well_column
      t.integer :subwell

      t.timestamps
    end
  end
end
