class PlateLocation < ApplicationRecord
  belongs_to :plate
  belongs_to :location

  validates :moved_at, presence: true
  validates :moved_by, presence: true

  scope :ordered_by_date, -> { order(:moved_at) }
  scope :recent_first, -> { order(moved_at: :desc) }
end
