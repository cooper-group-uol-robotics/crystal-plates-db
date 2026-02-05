class CreateDimensions < ActiveRecord::Migration[8.0]
  def change
    create_table :dimensions do |t|
      t.string :name, null: false
      t.string :symbol, null: false
      t.string :si_base_unit, null: false
      t.text :description

      t.timestamps
    end

    add_index :dimensions, :name, unique: true
    add_index :dimensions, :symbol, unique: true
  end
end
