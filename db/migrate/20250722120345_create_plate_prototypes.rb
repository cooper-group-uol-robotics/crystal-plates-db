class CreatePlatePrototypes < ActiveRecord::Migration[8.0]
  def change
    create_table :plate_prototypes do |t|
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
