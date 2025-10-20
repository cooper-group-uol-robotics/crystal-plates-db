class AddMassToWellContents < ActiveRecord::Migration[8.0]
  def change
    add_column :well_contents, :mass, :decimal, precision: 10, scale: 4
    add_column :well_contents, :mass_unit_id, :integer
    
    add_foreign_key :well_contents, :units, column: :mass_unit_id
    add_index :well_contents, :mass_unit_id
  end
end
