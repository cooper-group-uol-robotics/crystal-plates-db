class AddUbMatrixAndCellDataToScxrdDatasets < ActiveRecord::Migration[8.0]
  def change
    # Add UB matrix columns (9 components)
    add_column :scxrd_datasets, :ub11, :float
    add_column :scxrd_datasets, :ub12, :float
    add_column :scxrd_datasets, :ub13, :float
    add_column :scxrd_datasets, :ub21, :float
    add_column :scxrd_datasets, :ub22, :float
    add_column :scxrd_datasets, :ub23, :float
    add_column :scxrd_datasets, :ub31, :float
    add_column :scxrd_datasets, :ub32, :float
    add_column :scxrd_datasets, :ub33, :float
    
    # Add conventional cell parameters with centring
    add_column :scxrd_datasets, :conventional_a, :float
    add_column :scxrd_datasets, :conventional_b, :float
    add_column :scxrd_datasets, :conventional_c, :float
    add_column :scxrd_datasets, :conventional_alpha, :float
    add_column :scxrd_datasets, :conventional_beta, :float
    add_column :scxrd_datasets, :conventional_gamma, :float
    add_column :scxrd_datasets, :conventional_bravais, :string
    add_column :scxrd_datasets, :conventional_cb_op, :string
    add_column :scxrd_datasets, :conventional_distance, :float
  end
end
