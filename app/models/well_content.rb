class WellContent < ApplicationRecord
  belongs_to :well
  belongs_to :stock_solution
  belongs_to :unit, optional: true

  validates :volume, presence: true, numericality: { greater_than: 0 }
  validates :unit, presence: true, if: -> { volume.present? && volume > 0 }

  attr_accessor :volume_with_unit

  before_validation :parse_volume_with_unit_if_present

  def volume_with_unit
    return @volume_with_unit if @volume_with_unit.present?
    return volume.to_s if unit.nil?
    "#{volume} #{unit.symbol}"
  end

  def volume_with_unit=(value)
    @volume_with_unit = value
  end

  def display_volume
    return volume.to_s if unit.nil?
    "#{volume} #{unit.symbol}"
  end

  private

  def parse_volume_with_unit_if_present
    return unless @volume_with_unit.present?

    # Remove extra whitespace and normalize
    input = @volume_with_unit.strip

    # Try to match number followed by unit
    match = input.match(/^(\d+(?:\.\d+)?)\s*([a-zA-Zμ]+)$/)

    if match
      volume_value = match[1].to_f
      unit_symbol = match[2]

      # Normalize common unit symbol variations
      unit_symbol = normalize_unit_symbol(unit_symbol)

      # Find unit by symbol (case insensitive)
      found_unit = Unit.where("LOWER(symbol) = ?", unit_symbol.downcase).first

      if found_unit
        self.volume = volume_value
        self.unit = found_unit
      else
        # If unit not found, try to find by partial match
        found_unit = Unit.where("LOWER(symbol) LIKE ?", "%#{unit_symbol.downcase}%").first
        if found_unit
          self.volume = volume_value
          self.unit = found_unit
        else
          errors.add(:volume_with_unit, "Unknown unit: #{unit_symbol}")
        end
      end
    else
      # Try to parse as just a number (no unit)
      if input.match(/^\d+(?:\.\d+)?$/)
        self.volume = input.to_f
        self.unit = nil
      else
        errors.add(:volume_with_unit, "Invalid format. Please use format like '50 μL' or '1.5 mL'")
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
end
