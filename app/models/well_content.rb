class WellContent < ApplicationRecord
  belongs_to :well
  belongs_to :contentable, polymorphic: true
  belongs_to :stock_solution, optional: true  # Keep for backward compatibility
  belongs_to :unit, optional: true
  belongs_to :mass_unit, class_name: "Unit", optional: true

  validates :contentable, presence: true
  validate :contentable_must_be_valid_type
  validate :must_have_volume_or_mass
  validates :volume, numericality: { greater_than: 0 }, allow_nil: true
  validates :mass, numericality: { greater_than: 0 }, allow_nil: true
  validates :unit, presence: true, if: -> { volume.present? && volume > 0 }
  validates :mass_unit, presence: true, if: -> { mass.present? && mass > 0 }

  attr_accessor :volume_with_unit, :mass_with_unit

  before_validation :parse_volume_with_unit_if_present
  before_validation :parse_mass_with_unit_if_present

  def volume_with_unit
    return @volume_with_unit if @volume_with_unit.present?
    return volume.to_s if unit.nil?
    "#{volume} #{unit.symbol}"
  end

  def volume_with_unit=(value)
    @volume_with_unit = value
  end

  def mass_with_unit
    return @mass_with_unit if @mass_with_unit.present?
    return mass.to_s if mass_unit.nil?
    "#{mass} #{mass_unit.symbol}"
  end

  def mass_with_unit=(value)
    @mass_with_unit = value
  end

  def display_volume
    return volume.to_s if unit.nil?
    "#{volume} #{unit.symbol}"
  end

  def display_mass
    return mass.to_s if mass_unit.nil?
    "#{mass} #{mass_unit.symbol}"
  end

  def display_amount
    if has_mass?
      display_mass
    elsif has_volume?
      display_volume
    else
      "No amount specified"
    end
  end

  def has_volume?
    volume.present? && volume > 0
  end

  def has_mass?
    mass.present? && mass > 0
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

  def must_have_volume_or_mass
    unless has_volume? || has_mass?
      errors.add(:base, "Must specify either volume or mass")
    end

    if has_volume? && has_mass?
      errors.add(:base, "Cannot specify both volume and mass")
    end
  end

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

  def parse_mass_with_unit_if_present
    return unless @mass_with_unit.present?

    # Remove extra whitespace and normalize
    input = @mass_with_unit.strip

    # Try to match number followed by unit
    match = input.match(/^(\d+(?:\.\d+)?)\s*([a-zA-Zμ]+)$/)

    if match
      mass_value = match[1].to_f
      unit_symbol = match[2]

      # Normalize common unit symbol variations
      unit_symbol = normalize_unit_symbol(unit_symbol)

      # Find unit by symbol (case insensitive)
      found_unit = Unit.where("LOWER(symbol) = ?", unit_symbol.downcase).first

      if found_unit
        self.mass = mass_value
        self.mass_unit = found_unit
      else
        # If unit not found, try to find by partial match
        found_unit = Unit.where("LOWER(symbol) LIKE ?", "%#{unit_symbol.downcase}%").first
        if found_unit
          self.mass = mass_value
          self.mass_unit = found_unit
        else
          errors.add(:mass_with_unit, "Unknown unit: #{unit_symbol}")
        end
      end
    else
      # Try to parse as just a number (no unit)
      if input.match(/^\d+(?:\.\d+)?$/)
        self.mass = input.to_f
        self.mass_unit = nil
      else
        errors.add(:mass_with_unit, "Invalid format. Please use format like '50 mg' or '1.5 g'")
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
