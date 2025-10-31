class CalorimetryDatapoint < ApplicationRecord
  belongs_to :calorimetry_dataset

  validates :timestamp_seconds, :temperature, presence: true
  validates :timestamp_seconds, numericality: { greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:timestamp_seconds) }
  scope :in_time_range, ->(start_time, end_time) { where(timestamp_seconds: start_time..end_time) }

  # Delegate well for easy access
  delegate :well, to: :calorimetry_dataset
  delegate :calorimetry_video, to: :calorimetry_dataset
end
