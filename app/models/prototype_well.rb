class PrototypeWell < ApplicationRecord
  belongs_to :plate_prototype

  validates :well_row, :well_column, presence: true
  validates :x_mm, :y_mm, :z_mm, numericality: true, allow_nil: true
end
