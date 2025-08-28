class AddMeasuredAtToPxrdPatterns < ActiveRecord::Migration[8.0]
  def change
    add_column :pxrd_patterns, :measured_at, :datetime
  end
end
