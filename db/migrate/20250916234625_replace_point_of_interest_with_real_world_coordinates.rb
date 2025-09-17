class ReplacePointOfInterestWithRealWorldCoordinates < ActiveRecord::Migration[8.0]
  def change
    # Remove the point of interest relationship
    remove_reference :scxrd_datasets, :point_of_interest, foreign_key: true
    
    # Add real-world coordinates in millimeters
    add_column :scxrd_datasets, :real_world_x_mm, :decimal, precision: 8, scale: 3
    add_column :scxrd_datasets, :real_world_y_mm, :decimal, precision: 8, scale: 3
    add_column :scxrd_datasets, :real_world_z_mm, :decimal, precision: 8, scale: 3
  end
end
