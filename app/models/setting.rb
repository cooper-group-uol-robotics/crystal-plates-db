class Setting < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true

  # Class methods for easy access to settings
  class << self
    def get(key, default_value = nil)
      setting = find_by(key: key)
      setting&.value || default_value
    end

    def set(key, value, description = nil)
      setting = find_or_initialize_by(key: key)
      setting.value = value.to_s
      setting.description = description if description.present?
      setting.save!
      setting
    end

    def segmentation_api_endpoint
      get('segmentation_api_endpoint', 'http://aicdocker.liv.ac.uk:8000/segment/opencv')
    end

    def segmentation_api_timeout
      get('segmentation_api_timeout', '30').to_i
    end

    def auto_segment_point_type
      get('auto_segment_point_type', 'other')
    end
  end

  # Initialize default settings
  def self.initialize_defaults!
    [
      {
        key: 'segmentation_api_endpoint',
        value: 'http://aicdocker.liv.ac.uk:8000/segment/opencv',
        description: 'URL endpoint for the image segmentation API'
      },
      {
        key: 'segmentation_api_timeout',
        value: '30',
        description: 'Timeout in seconds for segmentation API requests'
      },
      {
        key: 'auto_segment_point_type',
        value: 'other',
        description: 'Default point type for auto-segmented points (crystal, particle, droplet, other)'
      }
    ].each do |setting_data|
      setting = find_or_initialize_by(key: setting_data[:key])
      if setting.new_record?
        setting.value = setting_data[:value]
        setting.description = setting_data[:description]
        setting.save!
      end
    end
  end
end
