class AddNameToPlates < ActiveRecord::Migration[8.0]
  def change
    add_column :plates, :name, :string
  end
end
