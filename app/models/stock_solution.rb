class StockSolution < ApplicationRecord
  has_many :stock_solution_components, dependent: :destroy
  has_many :chemicals, through: :stock_solution_components
  has_many :well_contents, dependent: :destroy
  has_many :wells, through: :well_contents

  validates :name, presence: true, uniqueness: true

  accepts_nested_attributes_for :stock_solution_components, allow_destroy: true, reject_if: :all_blank

  scope :with_components, -> { joins(:stock_solution_components).distinct }
  scope :by_name, ->(name) { where("name LIKE ?", "%#{name}%") }

  def display_name
    name.presence || "Stock Solution ##{id}"
  end

  def total_components
    stock_solution_components.count
  end

  def component_summary
    stock_solution_components.includes(:chemical, :unit).map do |component|
      "#{component.chemical.name}: #{component.amount} #{component.unit.symbol}"
    end.join(", ")
  end

  def used_in_wells_count
    well_contents.count
  end

  def can_be_deleted?
    well_contents.count == 0
  end
end
