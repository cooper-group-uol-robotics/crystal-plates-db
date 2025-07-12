class PlateLocation < ApplicationRecord
  belongs_to :plate
  belongs_to :location

  validates :moved_at, presence: true

  scope :ordered_by_date, -> { order(:moved_at) }
  scope :recent_first, -> { order(moved_at: :desc) }

  # Scope to get the most recent plate location for each plate
  # Using a subquery approach that works with SQLite
  scope :most_recent_for_each_plate, -> {
    where(
      id: PlateLocation.select("MAX(id)").group(:plate_id)
    )
  }
end
