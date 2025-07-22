class AddCoordinatesToWells < ActiveRecord::Migration[8.0]
  def change
    add_column :wells, :x_mm, :decimal, precision: 10, scale: 4, comment: "X coordinate in millimeters"
    add_column :wells, :y_mm, :decimal, precision: 10, scale: 4, comment: "Y coordinate in millimeters"
    add_column :wells, :z_mm, :decimal, precision: 10, scale: 4, comment: "Z coordinate in millimeters"
  end
end
