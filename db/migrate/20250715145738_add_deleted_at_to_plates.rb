class AddDeletedAtToPlates < ActiveRecord::Migration[8.0]
  def change
    add_column :plates, :deleted_at, :datetime
    add_index :plates, :deleted_at
  end
end
