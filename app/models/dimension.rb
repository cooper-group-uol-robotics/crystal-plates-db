class Dimension < ApplicationRecord
  has_many :units, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :symbol, presence: true, uniqueness: true
  validates :si_base_unit, presence: true

  scope :by_name, ->(name) { where(name: name) }

  def display_name
    "#{name} (#{symbol})"
  end

  def can_be_deleted?
    units.count == 0
  end
end
