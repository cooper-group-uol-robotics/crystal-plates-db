class CreateDiffractionImages < ActiveRecord::Migration[8.0]
  def change
    create_table :diffraction_images do |t|
      t.references :scxrd_dataset, null: false, foreign_key: true
      t.integer :run_number, null: false
      t.integer :image_number, null: false
      t.string :filename, null: false
      t.bigint :file_size

      t.timestamps
    end

    # Add indexes for efficient querying (scxrd_dataset_id index is automatically created by references)
    add_index :diffraction_images, [ :scxrd_dataset_id, :run_number, :image_number ],
              unique: true, name: 'index_diffraction_images_on_dataset_run_image'
    add_index :diffraction_images, [ :scxrd_dataset_id, :run_number ]
  end
end
