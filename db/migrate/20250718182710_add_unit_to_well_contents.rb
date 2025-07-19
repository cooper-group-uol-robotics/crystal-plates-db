class AddUnitToWellContents < ActiveRecord::Migration[8.0]
  def change
    add_reference :well_contents, :unit, null: true, foreign_key: true
    rename_column :well_contents, :volume_ul, :volume
  end
end
