class CalorimetryDataset < ApplicationRecord
  belongs_to :well
  belongs_to :calorimetry_video
  has_many :calorimetry_datapoints, dependent: :destroy

  validates :name, presence: true
  validates :pixel_x, :pixel_y, :mask_diameter_pixels, presence: true, numericality: { greater_than: 0 }
  validates :processed_at, presence: true

  scope :recent, -> { order(processed_at: :desc) }
  scope :for_well, ->(well) { where(well: well) }
  scope :for_video, ->(video) { where(calorimetry_video: video) }

  def datapoint_count
    calorimetry_datapoints.count
  end

  def temperature_range
    return [ nil, nil ] if calorimetry_datapoints.empty?

    temps = calorimetry_datapoints.pluck(:temperature)
    [ temps.min, temps.max ]
  end

  def duration_seconds
    return 0 if calorimetry_datapoints.empty?

    timestamps = calorimetry_datapoints.pluck(:timestamp_seconds)
    timestamps.max - timestamps.min
  end
end
