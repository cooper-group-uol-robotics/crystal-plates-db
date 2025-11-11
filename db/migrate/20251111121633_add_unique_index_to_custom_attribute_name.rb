class AddUniqueIndexToCustomAttributeName < ActiveRecord::Migration[8.0]
  def change
    # Remove the old scoped unique index
    remove_index :custom_attributes, name: "index_custom_attributes_on_attributable_and_name", if_exists: true
    
    # Add a new globally unique index on name
    add_index :custom_attributes, :name, unique: true, name: "index_custom_attributes_on_name_unique"
  end
end
