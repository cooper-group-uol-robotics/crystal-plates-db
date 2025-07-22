class AddPlatePrototypeIdToPlates < ActiveRecord::Migration[8.0]
  def change
    add_reference :plates, :plate_prototype, foreign_key: true
  end
end
