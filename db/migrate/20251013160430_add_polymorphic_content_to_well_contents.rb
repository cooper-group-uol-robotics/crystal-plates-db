class AddPolymorphicContentToWellContents < ActiveRecord::Migration[8.0]
  def up
    # Add polymorphic columns
    add_column :well_contents, :contentable_type, :string
    add_column :well_contents, :contentable_id, :integer
    
    # Add index for polymorphic association
    add_index :well_contents, [:contentable_type, :contentable_id]
    
    # Migrate existing data - all existing well_contents reference stock_solutions
    execute <<-SQL
      UPDATE well_contents 
      SET contentable_type = 'StockSolution', 
          contentable_id = stock_solution_id 
      WHERE stock_solution_id IS NOT NULL;
    SQL
    
    # Add validation to ensure at least one content type is specified
    # This will be enforced at the model level, but we can add a constraint
    
    # Make stock_solution_id nullable (it was required before)
    change_column_null :well_contents, :stock_solution_id, true
  end

  def down
    # Restore stock_solution_id as required for all existing records
    execute <<-SQL
      UPDATE well_contents 
      SET stock_solution_id = contentable_id 
      WHERE contentable_type = 'StockSolution' AND stock_solution_id IS NULL;
    SQL
    
    # Remove polymorphic columns
    remove_index :well_contents, [:contentable_type, :contentable_id]
    remove_column :well_contents, :contentable_id
    remove_column :well_contents, :contentable_type
    
    # Make stock_solution_id required again
    change_column_null :well_contents, :stock_solution_id, false
  end
end
