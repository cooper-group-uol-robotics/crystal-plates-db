class FixStockSolutionComponentsUnitReference < ActiveRecord::Migration[8.0]
  def change
    # Remove the old unit column
    remove_column :stock_solution_components, :unit, :integer

    # Add the proper unit_id foreign key reference
    add_reference :stock_solution_components, :unit, null: false, foreign_key: true
  end
end
