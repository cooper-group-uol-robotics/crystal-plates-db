class CreatePxrdPatterns < ActiveRecord::Migration[7.0]
  def change
    create_table :pxrd_patterns do |t|
      t.references :well, null: false, foreign_key: true
      t.string :title
      t.timestamps
    end
  end
end
