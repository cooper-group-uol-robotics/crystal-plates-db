class RemoveLocationFieldsFromPlates < ActiveRecord::Migration[8.0]
  def change
    remove_column :plates, :location_position, :integer
    remove_column :plates, :location_stack, :integer
  end
end
