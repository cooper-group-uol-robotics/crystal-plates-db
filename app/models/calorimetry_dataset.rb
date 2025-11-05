class CalorimetryDataset < ApplicationRecord
  belongs_to :well
  belongs_to :calorimetry_experiment
  has_many :calorimetry_datapoints, dependent: :destroy
  has_one_attached :temperature_data_file

  validates :name, presence: true
  validates :pixel_x, :pixel_y, :mask_diameter_pixels,
            presence: true,
            numericality: { greater_than: 0 }

  # Validate that we have either uploaded data or existing datapoints
  validate :must_have_temperature_data, on: :create

  scope :recent, -> { order(created_at: :desc) }
  scope :for_well, ->(well) { where(well: well) }
  scope :for_experiment, ->(experiment) { where(calorimetry_experiment: experiment) }

  after_create :process_uploaded_data, if: :temperature_data_file_attached?
  before_save :set_processed_at, if: :will_save_change_to_processed_at?

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

  private

  def must_have_temperature_data
    unless temperature_data_file.attached? || calorimetry_datapoints.any?
      errors.add(:temperature_data_file, "must be provided for new datasets")
    end
  end

  def set_processed_at
    self.processed_at = Time.current if processed_at.blank?
  end

  def process_uploaded_data
    return unless temperature_data_file.attached?

    begin
      csv_content = temperature_data_file.download
      datapoints = parse_csv_data(csv_content)

      # Create datapoints in batches for better performance
      CalorimetryDatapoint.insert_all(datapoints) if datapoints.any?

      # Set processed_at timestamp
      update_column(:processed_at, Time.current) if processed_at.blank?

    rescue => e
      Rails.logger.error "Failed to process calorimetry CSV: #{e.message}"
      errors.add(:temperature_data_file, "could not be processed: #{e.message}")
      throw :abort
    end
  end

  def parse_csv_data(csv_content)
    require "csv"

    datapoints = []
    csv = CSV.parse(csv_content, headers: true, header_converters: :symbol)

    csv.each_with_index do |row, index|
      begin
        timestamp = row[:timestamp_seconds]&.to_f
        temperature = row[:temperature]&.to_f

        if timestamp.nil? || temperature.nil?
          raise "Invalid data at row #{index + 2}: missing timestamp or temperature"
        end

        datapoints << {
          calorimetry_dataset_id: id,
          timestamp_seconds: timestamp,
          temperature: temperature,
          created_at: Time.current,
          updated_at: Time.current
        }

      rescue => e
        raise "Error parsing row #{index + 2}: #{e.message}"
      end
    end

    if datapoints.empty?
      raise "No valid data points found in CSV"
    end

    datapoints
  end
end
