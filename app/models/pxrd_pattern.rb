class PxrdPattern < ApplicationRecord
  belongs_to :well
  has_one_attached :xrdml_file

  # Optionally, you can add methods here to parse the xrdml file and extract data for plotting
end
