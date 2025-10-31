class CalorimetryVideo < ApplicationRecord
  belongs_to :plate
  has_one_attached :video_file
  has_many :calorimetry_datasets, dependent: :destroy

  validates :name, presence: true
  validates :recorded_at, presence: true

  scope :with_video, -> { joins(:video_file_attachment) }
  scope :recent, -> { order(recorded_at: :desc) }
end
