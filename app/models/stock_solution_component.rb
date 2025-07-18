class StockSolutionComponent < ApplicationRecord
  belongs_to :stock_solution
  belongs_to :chemical
  belongs_to :unit

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :chemical_id, uniqueness: { scope: :stock_solution_id, message: "can only be added once per stock solution" }

  delegate :name, to: :chemical, prefix: true
  delegate :symbol, to: :unit, prefix: true

  scope :by_chemical, ->(chemical_id) { where(chemical_id: chemical_id) }
  scope :ordered_by_chemical_name, -> { joins(:chemical).order("chemicals.name") }

  def display_amount
    "#{amount} #{unit.symbol}"
  end

  def formatted_component
    "#{chemical.name}: #{display_amount}"
  end
end
