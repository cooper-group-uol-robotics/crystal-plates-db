class AddProcessingLogToScxrdDatasets < ActiveRecord::Migration[8.0]
  def change
    add_column :scxrd_datasets, :processing_log, :text
  end
end
