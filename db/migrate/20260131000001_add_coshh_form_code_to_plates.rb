class AddCoshhFormCodeToPlates < ActiveRecord::Migration[8.0]
  def change
    add_column :plates, :coshh_form_code, :string
    add_index :plates, :coshh_form_code
  end
end
