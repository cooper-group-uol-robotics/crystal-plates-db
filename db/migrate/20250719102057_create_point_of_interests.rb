class CreatePointOfInterests < ActiveRecord::Migration[8.0]
  def change
    create_table :point_of_interests do |t|
      t.references :image, null: false, foreign_key: true
      t.integer :pixel_x, null: false
      t.integer :pixel_y, null: false
      t.string :point_type, null: false, default: 'crystal'
      t.text :description
      t.datetime :marked_at, null: false

      t.timestamps
    end

    add_index :point_of_interests, [ :image_id, :pixel_x, :pixel_y ], name: 'index_poi_on_image_and_coordinates'
    add_index :point_of_interests, :point_type
    add_index :point_of_interests, :marked_at
  end
end
