class WellScore < ApplicationRecord
  belongs_to :well
  belongs_to :custom_attribute

  validates :well_id, uniqueness: { scope: :custom_attribute_id, message: "already has a score for this attribute" }
  validate :value_matches_data_type

  scope :having_values, -> { where.not(value: nil) }
  scope :for_attribute, ->(attribute) { where(custom_attribute: attribute) }

  def display_value
    case custom_attribute.data_type
    when 'numeric'
      value&.to_f
    when 'text'
      string_value
    when 'json'
      json_value
    when 'boolean'
      value&.to_i == 1
    else
      value
    end
  end

  def set_display_value(val)
    case custom_attribute.data_type
    when 'numeric'
      self.value = val.to_f if val.present?
    when 'text'
      self.string_value = val.to_s
      self.value = nil
    when 'json'
      self.json_value = val
      self.value = nil
    when 'boolean'
      self.value = val.present? && val != false && val != '0' ? 1 : 0
    else
      self.value = val
    end
  end

  private

  def value_matches_data_type
    return if custom_attribute.nil?
    
    case custom_attribute.data_type
    when 'numeric'
      errors.add(:value, "must be numeric") if value.present? && !value.is_a?(Numeric)
    when 'text'
      errors.add(:string_value, "cannot be empty for text attributes") if string_value.blank?
    when 'json'
      errors.add(:json_value, "must be valid JSON") if json_value.present? && !json_value.is_a?(Hash) && !json_value.is_a?(Array)
    when 'boolean'
      errors.add(:value, "must be 0 or 1 for boolean attributes") if value.present? && ![0, 1].include?(value.to_i)
    end
  end
end