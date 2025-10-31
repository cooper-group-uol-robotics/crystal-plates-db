class CreateCalorimetryDatapoints < ActiveRecord::Migration[8.0]
  def change
    create_table :calorimetry_datapoints do |t|
      t.references :calorimetry_dataset, null: false, foreign_key: true
      t.decimal :timestamp_seconds, precision: 8, scale: 3, null: false
      t.decimal :temperature, precision: 8, scale: 3, null: false

      t.timestamps
    end

    add_index :calorimetry_datapoints, [:calorimetry_dataset_id, :timestamp_seconds], 
              name: 'index_calorimetry_datapoints_on_dataset_and_timestamp'
  end
end
