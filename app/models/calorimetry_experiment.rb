class CalorimetryExperiment < ApplicationRecord
  belongs_to :plate
  has_one_attached :video_file
  has_many :calorimetry_datasets, dependent: :destroy

  validates :name, presence: true
  validates :recorded_at, presence: true
  # Note: video_file is now optional - experiments may not always have video

  scope :with_video, -> { joins(:video_file_attachment) }
  scope :recent, -> { order(recorded_at: :desc) }
end
