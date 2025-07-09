class StockSolutionComponent < ApplicationRecord
  belongs_to :stock_solution
  belongs_to :chemical

  belongs_to :unit

  validates :amount, numericality: { greater_than: 0 }
end
