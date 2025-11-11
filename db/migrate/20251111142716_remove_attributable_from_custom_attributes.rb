class RemoveAttributableFromCustomAttributes < ActiveRecord::Migration[8.0]
  def change
    # Remove the old scoped unique index
    remove_index :custom_attributes, name: 'index_custom_attributes_uniqueness'
    
    # Remove the attributable index
    remove_index :custom_attributes, name: 'index_custom_attributes_on_attributable'
    
    # Remove the attributable columns (no longer needed since we only use global attributes)
    remove_column :custom_attributes, :attributable_type, :string
    remove_column :custom_attributes, :attributable_id, :integer
  end
end
