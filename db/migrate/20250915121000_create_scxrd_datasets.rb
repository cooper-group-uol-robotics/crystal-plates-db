class CreateScxrdDatasets < ActiveRecord::Migration[6.1]
  def change
    create_table :scxrd_datasets do |t|
      t.references :well, null: false, foreign_key: true
      t.references :lattice_centring, null: true, foreign_key: true
      t.string :experiment_name, null: false
      t.float :a, null: true
      t.float :b, null: true
      t.float :c, null: true
      t.float :alpha, null: true
      t.float :beta, null: true
      t.float :gamma, null: true
      t.date :date_measured, null: false
      t.datetime :date_uploaded, null: false, default: -> { 'CURRENT_TIMESTAMP' }
      t.timestamps
    end
  end
end
