class RemoveBlobColumnsFromScxrdDatasets < ActiveRecord::Migration[8.0]
  def change
    remove_column :scxrd_datasets, :rigaku_peak_table, :binary
    remove_column :scxrd_datasets, :first_diffraction_image, :binary
  end
end
