class CreateUnitCellSimilarities < ActiveRecord::Migration[8.0]
  def change
    create_table :unit_cell_similarities do |t|
      t.references :dataset_1, null: false, foreign_key: { to_table: :scxrd_datasets }
      t.references :dataset_2, null: false, foreign_key: { to_table: :scxrd_datasets }
      t.decimal :g6_distance, precision: 10, scale: 6, null: false

      t.timestamps
    end

    # Add unique index for dataset pairs and distance index for fast filtering
    add_index :unit_cell_similarities, [:dataset_1_id, :dataset_2_id], unique: true, name: 'index_similarities_on_dataset_pair'
    add_index :unit_cell_similarities, :g6_distance
  end
end
