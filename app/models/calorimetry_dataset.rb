class CalorimetryDataset < ApplicationRecord
  belongs_to :well
  belongs_to :calorimetry_video
  has_many :calorimetry_datapoints, dependent: :destroy
  has_one_attached :data_file

  validates :name, presence: true
  validates :pixel_x, :pixel_y, :mask_diameter_pixels, presence: true, numericality: { greater_than: 0 }
  validates :processed_at, presence: true

  # Parse and import data from uploaded file after file is attached
  after_commit :parse_and_import_data_file, if: :saved_change_to_id?

  scope :recent, -> { order(processed_at: :desc) }
  scope :for_well, ->(well) { where(well: well) }
  scope :for_video, ->(video) { where(calorimetry_video: video) }

  def datapoint_count
    calorimetry_datapoints.count
  end

  def temperature_range
    return [nil, nil] if calorimetry_datapoints.empty?
    
    temps = calorimetry_datapoints.pluck(:temperature)
    [temps.min, temps.max]
  end

  def duration_seconds
    return 0 if calorimetry_datapoints.empty?
    
    timestamps = calorimetry_datapoints.pluck(:timestamp_seconds)
    timestamps.max - timestamps.min
  end

  # Parse and import data from uploaded file
  def parse_and_import_data_file
    return unless data_file.attached?
    
    begin
      filename = data_file.filename.to_s.downcase
      file_content = data_file.download
      
      if filename.end_with?('.csv')
        parse_csv_data(file_content)
      elsif filename.end_with?('.json')
        parse_json_data(file_content)
      else
        Rails.logger.error "Unsupported file format for CalorimetryDataset #{id}: #{filename}"
      end
    rescue => e
      Rails.logger.error "Error parsing calorimetry data file for dataset #{id}: #{e.message}"
    end
  end

  # Manual parsing method that can be called after file upload
  def parse_and_import_data_file!
    parse_and_import_data_file
  end

  private

  def parse_csv_data(file_content)
    require 'csv'
    
    datapoints = []
    CSV.parse(file_content, headers: true) do |row|
      # Support various column name formats
      time_key = find_column_key(row.headers, ['time', 'timestamp', 'timestamp_seconds', 't'])
      temp_key = find_column_key(row.headers, ['temperature', 'temp', 'T'])
      
      next unless time_key && temp_key
      
      timestamp = row[time_key].to_f
      temperature = row[temp_key].to_f
      
      datapoints << {
        calorimetry_dataset_id: id,
        timestamp_seconds: timestamp,
        temperature: temperature,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    # Clear existing datapoints and bulk insert new ones
    calorimetry_datapoints.delete_all
    CalorimetryDatapoint.insert_all(datapoints) if datapoints.any?
    
    Rails.logger.info "Imported #{datapoints.count} datapoints from CSV for dataset #{id}"
  end

  def parse_json_data(file_content)
    data = JSON.parse(file_content)
    datapoints = []
    
    # Support various JSON formats
    if data.is_a?(Array)
      # Array of objects: [{"time": 0.0, "temperature": 25.0}, ...]
      data.each do |point|
        time_key = find_json_key(point, ['time', 'timestamp', 'timestamp_seconds', 't'])
        temp_key = find_json_key(point, ['temperature', 'temp', 'T'])
        
        next unless time_key && temp_key
        
        datapoints << {
          calorimetry_dataset_id: id,
          timestamp_seconds: point[time_key].to_f,
          temperature: point[temp_key].to_f,
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    elsif data.is_a?(Hash)
      # Object with arrays: {"time": [0, 1, 2], "temperature": [25.0, 25.1, 25.2]}
      time_key = find_json_key(data, ['time', 'timestamp', 'timestamp_seconds', 't'])
      temp_key = find_json_key(data, ['temperature', 'temp', 'T'])
      
      if time_key && temp_key && data[time_key].is_a?(Array) && data[temp_key].is_a?(Array)
        times = data[time_key]
        temperatures = data[temp_key]
        
        times.each_with_index do |time, index|
          next if index >= temperatures.length
          
          datapoints << {
            calorimetry_dataset_id: id,
            timestamp_seconds: time.to_f,
            temperature: temperatures[index].to_f,
            created_at: Time.current,
            updated_at: Time.current
          }
        end
      end
    end
    
    # Clear existing datapoints and bulk insert new ones
    calorimetry_datapoints.delete_all
    CalorimetryDatapoint.insert_all(datapoints) if datapoints.any?
    
    Rails.logger.info "Imported #{datapoints.count} datapoints from JSON for dataset #{id}"
  end

  def find_column_key(headers, possible_names)
    headers.find { |header| possible_names.any? { |name| header.downcase.include?(name.downcase) } }
  end

  def find_json_key(hash, possible_names)
    hash.keys.find { |key| possible_names.any? { |name| key.to_s.downcase.include?(name.downcase) } }
  end
end
