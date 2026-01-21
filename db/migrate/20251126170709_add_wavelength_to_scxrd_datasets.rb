class AddWavelengthToScxrdDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :scxrd_datasets, :wavelength, :float
  end
end
