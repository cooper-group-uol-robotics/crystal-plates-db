class Unit < ApplicationRecord
  has_many :stock_solution_components, dependent: :restrict_with_error
  has_many :well_contents, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :symbol, presence: true, uniqueness: true
  validates :conversion_to_base, presence: true, numericality: { greater_than: 0 }

  scope :by_symbol, ->(symbol) { where(symbol: symbol) }
  scope :by_name, ->(name) { where("LOWER(name) LIKE ?", "%#{name.downcase}%") }

  def display_name
    "#{name} (#{symbol})"
  end

  def can_be_deleted?
    stock_solution_components.count == 0 && well_contents.count == 0
  end
end
