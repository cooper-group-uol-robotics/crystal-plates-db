class AddDimensionsToPlates < ActiveRecord::Migration[8.0]
  def change
    add_column :plates, :rows, :integer, default: 8, null: false
    add_column :plates, :columns, :integer, default: 12, null: false
    add_column :plates, :subwells_per_well, :integer, default: 1, null: false

    # Add constraints
    add_check_constraint :plates, "rows > 0 AND rows <= 26", name: "plates_rows_range"
    add_check_constraint :plates, "columns > 0 AND columns <= 48", name: "plates_columns_range"
    add_check_constraint :plates, "subwells_per_well > 0 AND subwells_per_well <= 16", name: "plates_subwells_range"
  end
end
