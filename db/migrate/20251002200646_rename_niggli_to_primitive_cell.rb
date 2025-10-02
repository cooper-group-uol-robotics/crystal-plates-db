class RenameNiggliToPrimitiveCell < ActiveRecord::Migration[8.0]
  def change
    # Rename niggli columns to primitive columns to better reflect their meaning
    rename_column :scxrd_datasets, :niggli_a, :primitive_a
    rename_column :scxrd_datasets, :niggli_b, :primitive_b
    rename_column :scxrd_datasets, :niggli_c, :primitive_c
    rename_column :scxrd_datasets, :niggli_alpha, :primitive_alpha
    rename_column :scxrd_datasets, :niggli_beta, :primitive_beta
    rename_column :scxrd_datasets, :niggli_gamma, :primitive_gamma
  end
end
