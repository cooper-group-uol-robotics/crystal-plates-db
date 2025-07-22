class PlatePrototype < ApplicationRecord
  has_many :prototype_wells, dependent: :destroy

  validates :name, presence: true, uniqueness: true
end
