class LatticeCentring < ApplicationRecord
  has_many :scxrd_datasets

  validates :symbol, presence: true, uniqueness: true
end
