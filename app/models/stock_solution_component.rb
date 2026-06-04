class StockSolutionComponent < ApplicationRecord
  belongs_to :stock_solution
  belongs_to :chemical
  belongs_to :unit

  validates :chemical, presence: { message: "must be selected" }
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :unit, presence: { message: "must be specified (e.g., 10 mg, 5 ml)" }
  validates :chemical_id, uniqueness: { scope: :stock_solution_id, message: "can only be added once per stock solution" }

  # Virtual attribute for combined amount and unit input
  attr_accessor :amount_with_unit

  delegate :name, to: :chemical, prefix: true
  delegate :symbol, to: :unit, prefix: true

  scope :by_chemical, ->(chemical_id) { where(chemical_id: chemical_id) }
  scope :ordered_by_chemical_name, -> { joins(:chemical).order("chemicals.name") }

  # Callback to parse amount_with_unit before validation
  before_validation :parse_amount_with_unit, if: :amount_with_unit_changed?

  def display_amount
    "#{amount} #{unit&.symbol}"
  end

  def formatted_component
    "#{chemical.name}: #{display_amount}"
  end

  # Getter for the combined field
  def amount_with_unit
    @amount_with_unit || (amount && unit ? "#{amount} #{unit&.symbol}" : nil)
  end

  private

  def amount_with_unit_changed?
    @amount_with_unit.present?
  end

  def parse_amount_with_unit
    return unless @amount_with_unit.present?

    # Parse the input string to extract amount and unit
    parsed_data = parse_amount_string(@amount_with_unit)

    if parsed_data
      self.amount = parsed_data[:amount]
      self.unit = parsed_data[:unit]
    else
      # Clear the amount and unit to ensure validation fails
      self.amount = nil
      self.unit = nil
      errors.add(:amount_with_unit, "must be in format like '10 mg', '5.5 ml', etc.")
    end
  end

  def parse_amount_string(input)
    return nil unless input.present?

    # Clean the input string
    cleaned_input = input.strip

    # Regular expressions for different unit patterns
    unit_patterns = [
      # Common units with their variations
      { regex: /^([\d,.]+)\s*(mg|milligram|milligrams)$/i, unit_symbol: "mg" },
      { regex: /^([\d,.]+)\s*(g|gram|grams)$/i, unit_symbol: "g" },
      { regex: /^([\d,.]+)\s*(kg|kilogram|kilograms)$/i, unit_symbol: "kg" },
      { regex: /^([\d,.]+)\s*(µl|μl|ul|microliter|microliters)$/i, unit_symbol: "μL" },  # Accept both micro symbols
      { regex: /^([\d,.]+)\s*(ml|milliliter|milliliters)$/i, unit_symbol: "mL" },
      { regex: /^([\d,.]+)\s*(l|liter|liters)$/i, unit_symbol: "L" }
  ]

    # Try to match against each pattern
    unit_patterns.each do |pattern|
      match = cleaned_input.match(pattern[:regex])
      if match
        amount_str = match[1].gsub(",", "") # Remove commas from numbers
        amount_value = Float(amount_str) rescue nil

        if amount_value && amount_value > 0
          # Find the unit (case-insensitive lookup)
          unit = Unit.where("LOWER(symbol) = ?", pattern[:unit_symbol].downcase).first ||
                 Unit.where("LOWER(name) = ?", pattern[:unit_symbol].downcase).first

          if unit
            return { amount: amount_value, unit: unit }
          else
            # Log error - should not create units dynamically without proper dimension
            Rails.logger.error "Unit not found for symbol: #{pattern[:unit_symbol]}"
            errors.add(:amount_with_unit, "unknown unit '#{pattern[:unit_symbol]}'")
            return nil
          end
        end
      end
    end

    nil # No valid pattern found
  end
end
