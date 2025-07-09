class CreateWellContents < ActiveRecord::Migration[8.0]
  def change
    create_table :well_contents do |t|
      t.references :well, null: false, foreign_key: true
      t.references :stock_solution, null: false, foreign_key: true
      t.float :volume_ul

      t.timestamps
    end
  end
end
