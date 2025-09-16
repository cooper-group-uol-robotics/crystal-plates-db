class CreateLatticeCentrings < ActiveRecord::Migration[6.1]
  def change
    create_table :lattice_centrings do |t|
      t.string :symbol, null: false, unique: true
      t.string :description
      t.timestamps
    end
    add_index :lattice_centrings, :symbol, unique: true
  end
end
