class CreateChemicals < ActiveRecord::Migration[8.0]
  def change
    create_table :chemicals do |t|
      t.integer :sciformation_id

      t.timestamps
    end
  end
end
