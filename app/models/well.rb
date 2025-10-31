class Well < ApplicationRecord
  belongs_to :plate
  has_many :well_contents, dependent: :destroy
  has_many :stock_solutions, through: :well_contents

  # New polymorphic associations for direct chemical access
  has_many :chemical_contents, -> { where(contentable_type: "Chemical") }, class_name: "WellContent"
  has_many :chemicals, through: :chemical_contents, source: :contentable, source_type: "Chemical"

  has_many :stock_solution_contents, -> { where(contentable_type: "StockSolution") }, class_name: "WellContent"
  has_many :polymorphic_stock_solutions, through: :stock_solution_contents, source: :contentable, source_type: "StockSolution"
  has_many :images, dependent: :destroy
  has_many :point_of_interests, through: :images, dependent: :destroy

  has_many :pxrd_patterns, dependent: :destroy

  has_many :scxrd_datasets, dependent: :destroy

  has_many :calorimetry_datasets, dependent: :destroy

  validates :well_row, :well_column, presence: true
  validates :subwell, presence: true, numericality: { greater_than: 0 }
  validates :subwell, uniqueness: { scope: [ :plate_id, :well_row, :well_column ] }
  validates :x_mm, :y_mm, :z_mm, numericality: true, allow_nil: true

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
    if association(:images).loaded?
      images.any?
    else
      images.exists?
    end
  end

  # Check if well has any content (optimized for preloaded associations)
  def has_content?
    if association(:well_contents).loaded?
      well_contents.any?
    else
      well_contents.exists?
    end
  end

  # Check if well contains chemicals directly
  def has_chemicals?
    if association(:well_contents).loaded?
      well_contents.any? { |wc| wc.chemical? }
    else
      chemical_contents.exists?
    end
  end

  # Check if well contains stock solutions
  def has_stock_solutions?
    if association(:well_contents).loaded?
      well_contents.any? { |wc| wc.stock_solution? }
    else
      stock_solution_contents.exists?
    end
  end

  # Get all content items (both chemicals and stock solutions)
  def all_content_items
    well_contents.includes(:contentable).map(&:contentable).compact
  end

  # Get content summary
  def content_summary
    return "No content" unless has_content?

    summaries = []

    if has_chemicals?
      chemical_count = chemicals.count
      summaries << "#{chemical_count} chemical#{chemical_count == 1 ? '' : 's'}"
    end

    if has_stock_solutions?
      stock_solution_count = polymorphic_stock_solutions.count
      summaries << "#{stock_solution_count} stock solution#{stock_solution_count == 1 ? '' : 's'}"
    end

    summaries.join(", ")
  end

  # Check if well has any PXRD patterns
  def has_pxrd_patterns?
    if association(:pxrd_patterns).loaded?
      pxrd_patterns.any?
    else
      pxrd_patterns.exists?
    end
  end

  # Check if well has any SCXRD datasets
  def has_scxrd_datasets?
    if association(:scxrd_datasets).loaded?
      scxrd_datasets.any?
    else
      scxrd_datasets.exists?
    end
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

  # Coordinate methods
  def has_coordinates?
    x_mm.present? && y_mm.present? && z_mm.present?
  end

  def coordinates
    return nil unless has_coordinates?
    { x: x_mm, y: y_mm, z: z_mm }
  end

  def coordinates_formatted
    return "No coordinates" unless has_coordinates?
    "X: #{x_mm}mm, Y: #{y_mm}mm, Z: #{z_mm}mm"
  end

  def set_coordinates(x:, y:, z:)
    self.x_mm = x
    self.y_mm = y
    self.z_mm = z
  end
end
