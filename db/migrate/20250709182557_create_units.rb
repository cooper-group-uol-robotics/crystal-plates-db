class CreateUnits < ActiveRecord::Migration[8.0]
  def change
    create_table :units do |t|
      t.string :name
      t.string :symbol
      t.float :conversion_to_base

      t.timestamps
    end
  end
end
