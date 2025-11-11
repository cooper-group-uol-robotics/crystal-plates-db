class CreateWellScores < ActiveRecord::Migration[8.0]
  def change
    create_table :well_scores do |t|
      t.references :well, null: false, foreign_key: true
      t.references :custom_attribute, null: false, foreign_key: true
      t.decimal :value, precision: 10, scale: 3 # Support for decimal values with precision
      t.text :string_value  # For future non-numeric values
      t.json :json_value    # For future complex values

      t.timestamps
    end

    add_index :well_scores, [:well_id, :custom_attribute_id], unique: true, name: 'index_well_scores_uniqueness'
    # Note: index on custom_attribute_id is automatically created by t.references
  end
end
