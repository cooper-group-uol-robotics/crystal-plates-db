class CreateStockSolutionComponents < ActiveRecord::Migration[8.0]
  def change
    create_table :stock_solution_components do |t|
      t.references :stock_solution, null: false, foreign_key: true
      t.references :chemical, null: false, foreign_key: true
      t.float :amount
      t.integer :unit

      t.timestamps
    end
  end
end
