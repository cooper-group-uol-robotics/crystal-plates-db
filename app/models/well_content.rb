class WellContent < ApplicationRecord
  belongs_to :well
  belongs_to :stock_solution
end
