class Well < ApplicationRecord
  belongs_to :plate
  has_many :well_content, dependent: :destroy
  has_many :images, dependent: :destroy

  validates :well_row, :well_column, presence: true
  validates :subwell, presence: true, numericality: { greater_than: 0 }
  validates :subwell, uniqueness: { scope: [ :plate_id, :well_row, :well_column ] }

  scope :in_well, ->(row, column) { where(well_row: row, well_column: column) }
  scope :subwell_number, ->(number) { where(subwell: number) }

  ROW_LETTERS = ("A".."Z").to_a.freeze

  def well_label
    row_index = well_row.to_i - 1
    letter = ROW_LETTERS[row_index] || "?"
    "#{letter}#{well_column}"
  end

  # Alias for compatibility with system tests
  def column
    well_column
  end

  def row
    well_row
  end

  # Check if well has any images
  def has_images?
    images.any?
  end

  # Get the most recent image
  def latest_image
    images.recent.first
  end

  def well_label_with_subwell
    base_label = well_label
    return base_label if subwell.nil? || subwell == 1
    "#{base_label}:#{subwell}"
  end

  def subwell_label_alphabetic
    return well_label if subwell.nil? || subwell == 1

    subwell_letter = ("a".."z").to_a[subwell - 1] || "?"
    "#{well_label}#{subwell_letter}"
  end

  def subwell_label_grid(subwells_per_row: 2)
    return well_label if subwell.nil? || subwell == 1

    # Calculate grid position (assuming square grid)
    row_in_well = ((subwell - 1) / subwells_per_row) + 1
    col_in_well = ((subwell - 1) % subwells_per_row) + 1
    "#{well_label}.#{row_in_well}.#{col_in_well}"
  end

  def subwell_label_position(subwells_per_row: 2)
    return well_label if subwell.nil? || subwell == 1

    positions = %w[TL TR BL BR]  # Top-Left, Top-Right, Bottom-Left, Bottom-Right
    # Extend for larger grids if needed
    if subwells_per_row == 4
      positions = %w[TL TML TMR TR ML MML MMR MR BL BML BMR BR]
    end

    position = positions[subwell - 1] || subwell.to_s
    "#{well_label}-#{position}"
  end

  # Default subwell representation - can be customized
  def full_label
    well_label_with_subwell
  end
end
