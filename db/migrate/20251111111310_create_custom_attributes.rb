class CreateCustomAttributes < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_attributes do |t|
      t.string :name, null: false
      t.text :description
      t.string :data_type, null: false, default: 'numeric'
      t.string :attributable_type # null means global attribute
      t.integer :attributable_id

      t.timestamps
    end

    add_index :custom_attributes, [:attributable_type, :attributable_id], name: 'index_custom_attributes_on_attributable'
    add_index :custom_attributes, :name
    add_index :custom_attributes, [:name, :attributable_type, :attributable_id], 
              name: 'index_custom_attributes_uniqueness', unique: true
  end
end
