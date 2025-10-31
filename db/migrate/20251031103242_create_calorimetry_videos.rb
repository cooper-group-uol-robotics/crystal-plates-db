class CreateCalorimetryVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :calorimetry_videos do |t|
      t.references :plate, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.datetime :recorded_at

      t.timestamps
    end
  end
end
