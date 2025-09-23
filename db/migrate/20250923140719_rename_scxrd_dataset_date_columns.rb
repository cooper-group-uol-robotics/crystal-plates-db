class RenameScxrdDatasetDateColumns < ActiveRecord::Migration[8.0]
  def change
    # Rename date_measured to measured_at
    rename_column :scxrd_datasets, :date_measured, :measured_at
    
    # Remove date_uploaded column
    remove_column :scxrd_datasets, :date_uploaded, :datetime
  end
end
