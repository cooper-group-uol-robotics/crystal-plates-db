class MakeImageDimensionsOptional < ActiveRecord::Migration[8.0]
  def change
    change_column_null :images, :pixel_width, true
    change_column_null :images, :pixel_height, true
  end
end
