class WellContent < ApplicationRecord
  belongs_to :well
  belongs_to :contentable, polymorphic: true
  belongs_to :stock_solution, optional: true  # Keep for backward compatibility
  belongs_to :amount_unit, class_name: "Unit", optional: true

  validates :contentable, presence: true
  validate :contentable_must_be_valid_type
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :amount_unit, presence: true

  attr_accessor :amount_with_unit

  before_validation :parse_amount_with_unit_if_present

  def amount_with_unit
    return @amount_with_unit if @amount_with_unit.present?
    return amount.to_s if amount_unit.nil?
    "#{amount} #{amount_unit&.symbol}"
  end

  def amount_with_unit=(value)
    @amount_with_unit = value
  end

  def display_amount
    return amount.to_s if amount_unit.nil?
    "#{amount} #{amount_unit&.symbol}"
  end

  # Backward compatibility methods
  def volume
    return amount if amount_unit&.volume_unit?
    nil
  end

  def mass
    return amount if amount_unit&.mass_unit?
    nil
  end

  def unit
    return amount_unit if amount_unit&.volume_unit?
    nil
  end

  def mass_unit
    return amount_unit if amount_unit&.mass_unit?
    nil
  end

  def has_volume?
    amount.present? && amount > 0 && amount_unit&.volume_unit?
  end

  def has_mass?
    amount.present? && amount > 0 && amount_unit&.mass_unit?
  end

  def volume_with_unit
    return display_amount if has_volume?
    nil
  end

  def volume_with_unit=(value)
    self.amount_with_unit = value
  end

  def mass_with_unit
    return display_amount if has_mass?
    nil
  end

  def mass_with_unit=(value)
    self.amount_with_unit = value
  end

  def display_volume
    return display_amount if has_volume?
    nil
  end

  def display_mass
    return display_amount if has_mass?
    nil
  end

  # Helper methods to determine content type
  def stock_solution?
    contentable_type == "StockSolution"
  end

  def chemical?
    contentable_type == "Chemical"
  end

  def content_name
    return contentable.display_name if stock_solution? && contentable.respond_to?(:display_name)
    return contentable.name if contentable.respond_to?(:name)
    return contentable.to_s if contentable
    "Unknown Content"
  end

  def content_description
    if stock_solution?
      "Stock Solution: #{content_name}"
    elsif chemical?
      "Chemical: #{content_name}"
    else
      content_name
    end
  end

  private

  def parse_amount_with_unit_if_present
    return unless @amount_with_unit.present?

    # Remove extra whitespace and normalize
    input = @amount_with_unit.strip

    # Try to match number followed by unit
    match = input.match(/^(\d+(?:\.\d+)?)\s*([a-zA-Zμ]+)$/)

    if match
      amount_value = match[1].to_f
      unit_symbol = match[2]

      # Normalize common unit symbol variations
      unit_symbol = normalize_unit_symbol(unit_symbol)
      
      Rails.logger.debug "Parsing amount with unit: '#{input}' -> amount: #{amount_value}, unit: '#{unit_symbol}'"

      # Find unit by symbol (case insensitive)
      found_unit = Unit.where("LOWER(symbol) = ?", unit_symbol.downcase).first

      if found_unit
        self.amount = amount_value
        self.amount_unit = found_unit
      else
        # If unit not found, try to find by partial match
        found_unit = Unit.where("LOWER(symbol) LIKE ?", "%#{unit_symbol.downcase}%").first
        if found_unit
          self.amount = amount_value
          self.amount_unit = found_unit
        else
          errors.add(:amount_with_unit, "Unknown unit: #{unit_symbol}")
        end
      end
    else
      # Try to parse as just a number (no unit)
      if input.match(/^\d+(?:\.\d+)?$/)
        self.amount = input.to_f
        self.amount_unit = nil
      else
        errors.add(:amount_with_unit, "Invalid format. Please use format like '50 μL' or '1.5 mg'")
      end
    end
  end

  def normalize_unit_symbol(symbol)
    # Handle common variations
    case symbol.downcase
    when "ul", "μl", "µl"
      "µl"
    when "ml", "mL"
      "ml"
    when "nl", "nL"
      "nl"
    when "l", "L"
      "l"
    when "g", "G"
      "g"
    when "mg", "mG", "Mg", "MG"
      "mg"
    when "kg", "kG", "Kg", "KG"
      "kg"
    else
      symbol
    end
  end

  def contentable_must_be_valid_type
    return unless contentable_type.present?

    allowed_types = [ "StockSolution", "Chemical" ]
    unless allowed_types.include?(contentable_type)
      errors.add(:contentable_type, "must be one of: #{allowed_types.join(', ')}")
    end
  end
end
