class AddFieldsToChemicals < ActiveRecord::Migration[8.0]
  def change
    add_column :chemicals, :name, :string
    add_column :chemicals, :smiles, :text
    add_column :chemicals, :cas, :string
    add_column :chemicals, :amount, :string
    add_column :chemicals, :storage, :text
    add_column :chemicals, :barcode, :string

    # Add indexes for commonly searched fields
    add_index :chemicals, :name
    add_index :chemicals, :cas
    add_index :chemicals, :barcode
  end
end
