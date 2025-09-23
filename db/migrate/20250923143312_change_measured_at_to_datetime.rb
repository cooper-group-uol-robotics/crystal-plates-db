class ChangeMeasuredAtToDatetime < ActiveRecord::Migration[8.0]
  def change
    # Change measured_at from date to datetime to include time information
    change_column :scxrd_datasets, :measured_at, :datetime
  end
end
