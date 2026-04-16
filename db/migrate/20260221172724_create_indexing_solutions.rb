class CreateIndexingSolutions < ActiveRecord::Migration[8.0]
  def change
    create_table :indexing_solutions do |t|
      t.references :scxrd_dataset, null: false, foreign_key: true, index: true

      # UB matrix components (orientation matrix)
      t.float :ub11
      t.float :ub12
      t.float :ub13
      t.float :ub21
      t.float :ub22
      t.float :ub23
      t.float :ub31
      t.float :ub32
      t.float :ub33
      t.float :wavelength

      # Primitive unit cell parameters
      t.float :primitive_a
      t.float :primitive_b
      t.float :primitive_c
      t.float :primitive_alpha
      t.float :primitive_beta
      t.float :primitive_gamma

      # Conventional unit cell parameters
      t.float :conventional_a
      t.float :conventional_b
      t.float :conventional_c
      t.float :conventional_alpha
      t.float :conventional_beta
      t.float :conventional_gamma
      t.string :conventional_bravais
      t.string :conventional_cb_op
      t.float :conventional_distance

      # Indexing statistics
      t.integer :spots_found
      t.integer :spots_indexed

      # Source tracking (e.g., "CIF", "PAR", "Manual", "Migrated from dataset")
      t.string :source

      t.timestamps
    end

    # Index for efficiently finding best solution (highest indexing rate)
    add_index :indexing_solutions, :spots_indexed
    add_index :indexing_solutions, [:scxrd_dataset_id, :spots_indexed]
  end
end
