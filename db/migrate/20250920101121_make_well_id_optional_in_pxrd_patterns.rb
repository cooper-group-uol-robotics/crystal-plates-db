class MakeWellIdOptionalInPxrdPatterns < ActiveRecord::Migration[8.0]
  def up
    change_column :pxrd_patterns, :well_id, :bigint, null: true
    remove_foreign_key :pxrd_patterns, :wells if foreign_key_exists?(:pxrd_patterns, :wells)
    add_foreign_key :pxrd_patterns, :wells, on_delete: :nullify
  end
  def down
    change_column :pxrd_patterns, :well_id, :bigint, null: false
    remove_foreign_key :pxrd_patterns, :wells if foreign_key_exists?(:pxrd_patterns, :wells)
    add_foreign_key :pxrd_patterns, :wells
  end
end
