class Well < ApplicationRecord
  belongs_to :plate
  has_many :well_content, dependent: :destroy
  has_many_attached :images

  ROW_LETTERS = ('A'..'Z').to_a.freeze

  def well_label
    row_index = well_row.to_i - 1
    letter = ROW_LETTERS[row_index] || '?'
    "#{letter}#{well_column}"
  end
end
