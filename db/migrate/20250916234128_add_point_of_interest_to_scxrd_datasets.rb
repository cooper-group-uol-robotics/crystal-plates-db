class AddPointOfInterestToScxrdDatasets < ActiveRecord::Migration[8.0]
  def change
    add_reference :scxrd_datasets, :point_of_interest, null: true, foreign_key: true
  end
end
