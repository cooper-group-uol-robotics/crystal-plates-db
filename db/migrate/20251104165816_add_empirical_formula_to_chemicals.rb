class AddEmpiricalFormulaToChemicals < ActiveRecord::Migration[8.0]
  def change
    add_column :chemicals, :empirical_formula, :string
  end
end
