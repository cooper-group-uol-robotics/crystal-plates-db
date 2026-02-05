class ConsolidateWellContentToAmountSystem < ActiveRecord::Migration[8.0]
  def up
    # Add dimension_id column to units table (dimension table will be created by a separate migration)
    add_column :units, :dimension_id, :integer
    add_index :units, :dimension_id

    # Note: Dimensions will be seeded after this migration runs
    # For now, we'll update units in the seeds.rb file

    # Add new amount columns to well_contents
    add_column :well_contents, :amount, :decimal, precision: 10, scale: 4
    add_column :well_contents, :amount_unit_id, :integer
    add_index :well_contents, :amount_unit_id

    # Migrate existing volume data to amount
    execute <<~SQL
      UPDATE well_contents 
      SET amount = volume, amount_unit_id = unit_id 
      WHERE volume IS NOT NULL AND unit_id IS NOT NULL
    SQL

    # Migrate existing mass data to amount (only if no volume was set)
    execute <<~SQL
      UPDATE well_contents 
      SET amount = mass, amount_unit_id = mass_unit_id 
      WHERE mass IS NOT NULL AND mass_unit_id IS NOT NULL AND amount IS NULL
    SQL

    # Add foreign key constraint for amount_unit_id
    add_foreign_key :well_contents, :units, column: :amount_unit_id

    # Remove old columns and their associated indexes/foreign keys
    begin
      remove_foreign_key :well_contents, column: :mass_unit_id
    rescue ArgumentError
      # Foreign key doesn't exist, which is fine
    end
    
    begin
      remove_foreign_key :well_contents, column: :unit_id
    rescue ArgumentError
      # Foreign key doesn't exist, which is fine
    end
    
    remove_index :well_contents, :mass_unit_id if index_exists?(:well_contents, :mass_unit_id)
    remove_index :well_contents, :unit_id if index_exists?(:well_contents, :unit_id)
    
    remove_column :well_contents, :volume
    remove_column :well_contents, :unit_id
    remove_column :well_contents, :mass
    remove_column :well_contents, :mass_unit_id

    # Add foreign key constraint for dimension_id (will be populated by seeds)
    add_foreign_key :units, :dimensions, column: :dimension_id
  end

  def down
    # Restore old columns
    add_column :well_contents, :volume, :float
    add_column :well_contents, :unit_id, :integer
    add_column :well_contents, :mass, :decimal, precision: 10, scale: 4
    add_column :well_contents, :mass_unit_id, :integer

    # Restore data from amount system - volume units
    execute <<~SQL
      UPDATE well_contents 
      SET volume = amount, unit_id = amount_unit_id
      FROM units u 
      JOIN dimensions d ON u.dimension_id = d.id
      WHERE well_contents.amount_unit_id = u.id AND d.symbol = 'V'
    SQL

    # Restore data from amount system - mass units  
    execute <<~SQL
      UPDATE well_contents 
      SET mass = amount, mass_unit_id = amount_unit_id
      FROM units u 
      JOIN dimensions d ON u.dimension_id = d.id
      WHERE well_contents.amount_unit_id = u.id AND d.symbol = 'M'
    SQL

    # Restore indexes and foreign keys
    add_index :well_contents, :unit_id unless index_exists?(:well_contents, :unit_id)
    add_index :well_contents, :mass_unit_id unless index_exists?(:well_contents, :mass_unit_id) 
    
    begin
      add_foreign_key :well_contents, :units, column: :unit_id
    rescue ActiveRecord::InvalidForeignKey
      # Foreign key already exists or other constraint issue
    end
    
    begin
      add_foreign_key :well_contents, :units, column: :mass_unit_id
    rescue ActiveRecord::InvalidForeignKey
      # Foreign key already exists or other constraint issue
    end

    # Remove new columns and indexes
    begin
      remove_foreign_key :well_contents, column: :amount_unit_id
    rescue ArgumentError
      # Foreign key doesn't exist, which is fine
    end
    remove_index :well_contents, :amount_unit_id if index_exists?(:well_contents, :amount_unit_id)
    remove_column :well_contents, :amount
    remove_column :well_contents, :amount_unit_id

    # Remove dimension_id from units and clean up dimensions
    begin
      remove_foreign_key :units, column: :dimension_id
    rescue ArgumentError
      # Foreign key doesn't exist, which is fine  
    end
    remove_index :units, :dimension_id if index_exists?(:units, :dimension_id)
    remove_column :units, :dimension_id

    # Clean up dimensions table (this will be handled by the separate dimension migration rollback)
  end
end
