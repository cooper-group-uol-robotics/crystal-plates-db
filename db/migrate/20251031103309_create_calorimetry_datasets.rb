class CreateCalorimetryDatasets < ActiveRecord::Migration[8.0]
  def change
    create_table :calorimetry_datasets do |t|
      t.references :well, null: false, foreign_key: true
      t.references :calorimetry_video, null: false, foreign_key: true
      t.string :name
      t.integer :pixel_x
      t.integer :pixel_y
      t.integer :mask_diameter_pixels
      t.datetime :processed_at

      t.timestamps
    end
  end
end
