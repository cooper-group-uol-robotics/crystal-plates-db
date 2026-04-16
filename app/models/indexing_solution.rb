class IndexingSolution < ApplicationRecord
  belongs_to :scxrd_dataset

  # Validations matching ScxrdDataset validations for consistency
  validates :primitive_a, :primitive_b, :primitive_c, :primitive_alpha, :primitive_beta, :primitive_gamma, 
            numericality: { greater_than: 0 }, allow_nil: true
  validates :conventional_a, :conventional_b, :conventional_c, :conventional_alpha, :conventional_beta, :conventional_gamma, 
            numericality: { greater_than: 0 }, allow_nil: true
  validates :ub11, :ub12, :ub13, :ub21, :ub22, :ub23, :ub31, :ub32, :ub33, 
            numericality: true, allow_nil: true
  validates :conventional_distance, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :spots_found, :spots_indexed, 
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :ordered_by_quality, -> { 
    order(Arel.sql('spots_indexed DESC NULLS LAST, created_at DESC')) 
  }
  scope :with_ub_matrix, -> { 
    where.not(ub11: nil, ub12: nil, ub13: nil, ub21: nil, ub22: nil, ub23: nil, ub31: nil, ub32: nil, ub33: nil) 
  }
  scope :with_primitive_cells, -> {
    where.not(
      primitive_a: nil, primitive_b: nil, primitive_c: nil,
      primitive_alpha: nil, primitive_beta: nil, primitive_gamma: nil
    )
  }

  # Callback to compute similarities when solution is created or unit cell data changes
  after_create :compute_unit_cell_similarities, if: :has_primitive_cell?
  after_update :compute_unit_cell_similarities, if: -> { saved_change_to_primitive_cell? && has_primitive_cell? }

  # Predicate methods
  def has_ub_matrix?
    ub11.present? && ub12.present? && ub13.present? &&
    ub21.present? && ub22.present? && ub23.present? &&
    ub31.present? && ub32.present? && ub33.present?
  end

  def has_primitive_cell?
    primitive_a.present? && primitive_b.present? && primitive_c.present? &&
    primitive_alpha.present? && primitive_beta.present? && primitive_gamma.present?
  end

  def has_conventional_cell?
    conventional_a.present? && conventional_b.present? && conventional_c.present? &&
    conventional_alpha.present? && conventional_beta.present? && conventional_gamma.present?
  end

  # Helper methods
  def ub_matrix_as_array
    return nil unless has_ub_matrix?
    [
      [ub11, ub12, ub13],
      [ub21, ub22, ub23],
      [ub31, ub32, ub33]
    ]
  end

  def cell_parameters_from_ub_matrix
    return nil unless has_ub_matrix?
    UbMatrixService.ub_matrix_to_cell_parameters(
      ub11, ub12, ub13,
      ub21, ub22, ub23,
      ub31, ub32, ub33,
      wavelength || 0.71073  # Default to Mo wavelength if not set
    )
  end

  # Calculated indexing rate percentage
  def indexing_rate
    return nil unless spots_found.present? && spots_indexed.present? && spots_found > 0
    (spots_indexed.to_f / spots_found * 100).round(2)
  end

  # Display label for the solution
  def display_label
    parts = []
    parts << source if source.present?
    parts << "(#{indexing_rate}% indexed)" if indexing_rate.present?
    parts << "created #{created_at.strftime('%Y-%m-%d %H:%M')}" if created_at.present?
    
    parts.any? ? parts.join(' ') : "Solution ##{id}"
  end

  private

  # Check if primitive cell parameters have changed
  def saved_change_to_primitive_cell?
    saved_change_to_primitive_a? || saved_change_to_primitive_b? || saved_change_to_primitive_c? ||
    saved_change_to_primitive_alpha? || saved_change_to_primitive_beta? || saved_change_to_primitive_gamma?
  end

  # Trigger similarity computation in background
  def compute_unit_cell_similarities
    UnitCellSimilarityComputationService.perform_later(scxrd_dataset)
  end
end
