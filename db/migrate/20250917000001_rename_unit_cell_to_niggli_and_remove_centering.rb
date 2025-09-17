class RenameUnitCellToNiggliAndRemoveCentering < ActiveRecord::Migration[7.1]
  def change
    # Rename unit cell columns to indicate they are Niggli reduced cell parameters
    rename_column :scxrd_datasets, :a, :niggli_a
    rename_column :scxrd_datasets, :b, :niggli_b
    rename_column :scxrd_datasets, :c, :niggli_c
    rename_column :scxrd_datasets, :alpha, :niggli_alpha
    rename_column :scxrd_datasets, :beta, :niggli_beta
    rename_column :scxrd_datasets, :gamma, :niggli_gamma
    
    # Remove lattice centering since Niggli cells are always primitive
    remove_foreign_key :scxrd_datasets, :lattice_centrings
    remove_index :scxrd_datasets, :lattice_centring_id
    remove_column :scxrd_datasets, :lattice_centring_id, :integer
  end
end