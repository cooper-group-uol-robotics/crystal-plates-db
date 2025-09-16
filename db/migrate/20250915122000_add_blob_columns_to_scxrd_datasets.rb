class AddBlobColumnsToScxrdDatasets < ActiveRecord::Migration[6.1]
  def change
    add_column :scxrd_datasets, :rigaku_peak_table, :binary
    add_column :scxrd_datasets, :first_diffraction_image, :binary
  end
end
