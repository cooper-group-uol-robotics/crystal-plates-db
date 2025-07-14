class CreateImages < ActiveRecord::Migration[8.0]
  def change
    create_table :images do |t|
      t.references :well, null: false, foreign_key: true

      # Pixel size in millimeters (precision: 10 digits total, 6 decimal places)
      t.decimal :pixel_size_x_mm, precision: 10, scale: 6, null: false
      t.decimal :pixel_size_y_mm, precision: 10, scale: 6, null: false

      # Reference point coordinates in millimeters (precision: 12 digits total, 6 decimal places)
      t.decimal :reference_x_mm, precision: 12, scale: 6, null: false
      t.decimal :reference_y_mm, precision: 12, scale: 6, null: false
      t.decimal :reference_z_mm, precision: 12, scale: 6, null: false

      # Image pixel dimensions (can be auto-detected from file)
      t.integer :pixel_width
      t.integer :pixel_height

      # Optional fields for additional metadata
      t.string :description
      t.datetime :captured_at

      t.timestamps
    end

    # Add index for captured_at (well_id already has index from t.references)
    add_index :images, :captured_at
  end
end
