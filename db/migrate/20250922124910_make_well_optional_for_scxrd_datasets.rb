class MakeWellOptionalForScxrdDatasets < ActiveRecord::Migration[8.0]
  def change
    change_column_null :scxrd_datasets, :well_id, true
  end
end
