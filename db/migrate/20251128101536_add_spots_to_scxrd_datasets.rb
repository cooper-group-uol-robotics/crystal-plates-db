class AddSpotsToScxrdDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :scxrd_datasets, :spots_found, :integer
    add_column :scxrd_datasets, :spots_indexed, :integer
  end
end
