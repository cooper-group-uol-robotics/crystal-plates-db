class ScxrdDataset < ApplicationRecord
  belongs_to :well, optional: true
  has_many :diffraction_images, dependent: :destroy
  has_one_attached :archive
  has_one_attached :peak_table
  has_one_attached :crystal_image
  has_one_attached :structure_file

  # Unit cell similarity associations
  has_many :unit_cell_similarities_as_dataset_1, 
           class_name: 'UnitCellSimilarity', 
           foreign_key: 'dataset_1_id',
           dependent: :destroy
  has_many :unit_cell_similarities_as_dataset_2, 
           class_name: 'UnitCellSimilarity', 
           foreign_key: 'dataset_2_id',
           dependent: :destroy

  validates :experiment_name, :measured_at, presence: true
  validates :primitive_a, :primitive_b, :primitive_c, :primitive_alpha, :primitive_beta, :primitive_gamma, numericality: { greater_than: 0 }, allow_nil: true
  validates :conventional_a, :conventional_b, :conventional_c, :conventional_alpha, :conventional_beta, :conventional_gamma, numericality: { greater_than: 0 }, allow_nil: true
  validates :ub11, :ub12, :ub13, :ub21, :ub22, :ub23, :ub31, :ub32, :ub33, numericality: true, allow_nil: true
  validates :conventional_distance, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :real_world_x_mm, :real_world_y_mm, :real_world_z_mm, numericality: true, allow_nil: true
  validates :spots_found, :spots_indexed, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Callback to compute similarities when dataset is created or unit cell data changes
  after_create :compute_unit_cell_similarities, if: :has_primitive_cell?
  after_update :compute_unit_cell_similarities, if: -> { saved_change_to_primitive_cell? && has_primitive_cell? }

  # Processing log methods
  def has_processing_log?
    processing_log.present?
  end

  def processing_log_lines
    return [] unless has_processing_log?
    processing_log.split("\n")
  end

  # Scopes
  scope :with_coordinates, -> { where.not(real_world_x_mm: nil, real_world_y_mm: nil) }
  scope :near_coordinates, ->(x_mm, y_mm, tolerance_mm = 0.5) {
    with_coordinates.where(
      "(ABS(real_world_x_mm - ?) + ABS(real_world_y_mm - ?)) <= ?",
      x_mm, y_mm, tolerance_mm * 1.4142 # Manhattan distance approximation
    )
  }
  scope :with_primitive_cells, -> {
    where.not(
      primitive_a: nil, primitive_b: nil, primitive_c: nil,
      primitive_alpha: nil, primitive_beta: nil, primitive_gamma: nil
    )
  }

  # Class methods for unit cell operations
  def self.all_unit_cells
    # Efficiently fetch all unit cell parameters for datasets that have complete primitive cells
    with_primitive_cells.pluck(
      :id, :experiment_name,
      :primitive_a, :primitive_b, :primitive_c,
      :primitive_alpha, :primitive_beta, :primitive_gamma
    ).map do |id, name, a, b, c, alpha, beta, gamma|
      {
        dataset_id: id,
        experiment_name: name,
        unit_cell: {
          a: a, b: b, c: c,
          alpha: alpha, beta: beta, gamma: gamma
        }
      }
    end
  end

  def self.unit_cells_for_api(exclude_id: nil)
    # Get unit cell data formatted for the G6 distance API
    query = with_primitive_cells
    query = query.where.not(id: exclude_id) if exclude_id

    query.pluck(
      :id,
      :primitive_a, :primitive_b, :primitive_c,
      :primitive_alpha, :primitive_beta, :primitive_gamma
    ).map do |id, a, b, c, alpha, beta, gamma|
      {
        dataset_id: id,
        cell_params: [ a.to_f, b.to_f, c.to_f, alpha.to_f, beta.to_f, gamma.to_f ]
      }
    end
  end

  # Spatial correlation methods
  def has_real_world_coordinates?
    real_world_x_mm.present? && real_world_y_mm.present?
  end

  def distance_to_coordinates(x_mm, y_mm, z_mm = nil)
    return nil unless has_real_world_coordinates?
    return nil unless x_mm.present? && y_mm.present?

    dx = real_world_x_mm - x_mm
    dy = real_world_y_mm - y_mm

    if z_mm.present? && real_world_z_mm.present?
      dz = real_world_z_mm - z_mm
      Math.sqrt(dx**2 + dy**2 + dz**2)
    else
      Math.sqrt(dx**2 + dy**2)
    end
  end

  def nearby_point_of_interests(tolerance_mm = 0.5)
    return PointOfInterest.none unless has_real_world_coordinates?
    return PointOfInterest.none unless well.present?

    # Get all points of interest from images in the same well
    poi_candidates = well.images.joins(:point_of_interests).includes(:point_of_interests)
                        .flat_map(&:point_of_interests)

    # Filter by distance using existing real-world coordinate conversion
    poi_candidates.select do |poi|
      coords = poi.real_world_coordinates
      next false unless coords[:x_mm].present? && coords[:y_mm].present?

      distance_to_coordinates(coords[:x_mm], coords[:y_mm], coords[:z_mm]) <= tolerance_mm
    end
  end

  # Class method to find spatial correlations for a well
  def self.spatial_correlations_for_well(well, tolerance_mm = 0.5)
    correlations = []

    well.scxrd_datasets.with_coordinates.each do |dataset|
      nearby_pois = dataset.nearby_point_of_interests(tolerance_mm)
      if nearby_pois.any?
        correlations << {
          scxrd_dataset: dataset,
          point_of_interests: nearby_pois,
          distances: nearby_pois.map { |poi|
            coords = poi.real_world_coordinates
            {
              poi: poi,
              distance_mm: dataset.distance_to_coordinates(coords[:x_mm], coords[:y_mm], coords[:z_mm])
            }
          }
        }
      end
    end

    correlations
  end

  def has_peak_table?
    peak_table.attached?
  end

  def has_crystal_image?
    crystal_image.attached?
  end

  def has_structure_file?
    structure_file.attached?
  end

  def structure_file_format
    return nil unless has_structure_file?

    filename = structure_file.filename.to_s.downcase
    if filename.end_with?(".ins")
      "ins"
    elsif filename.end_with?(".res")
      "res"
    elsif filename.end_with?(".cif")
      "cif"
    else
      "unknown"
    end
  end

  def has_first_image?
    diffraction_images.any?
  end

  def peak_table_size
    return 0 unless peak_table.attached?
    peak_table.blob.byte_size
  end

  def first_image_size
    first_diffraction_image = diffraction_images.order(:run_number, :image_number).first
    return 0 unless first_diffraction_image&.rodhypix_file&.attached?
    first_diffraction_image.rodhypix_file.blob.byte_size
  end

  # Diffraction images methods
  def has_diffraction_images?
    diffraction_images.any?
  end

  def diffraction_images_count
    diffraction_images.count
  end

  def runs_available
    diffraction_images.distinct.pluck(:run_number).sort
  end

  def first_diffraction_image
    diffraction_images.ordered.first
  end

  def total_diffraction_images_size
    diffraction_images.sum(&:file_size) || 0
  end

  def image_metadata_only(diffraction_image: nil)
    # Fast metadata extraction without full decompression
    image_source = diffraction_image&.rodhypix_file || diffraction_images.order(:run_number, :image_number).first&.rodhypix_file
    return { success: false, error: "No image file attached" } unless image_source&.attached?

    begin
      # Download the image data
      image_data = image_source.blob.download

      # Parse just the header using the ROD parser service
      parser = RodImageParserService.new(image_data)
      metadata = parser.parse_header_only

      metadata
    rescue => e
      Rails.logger.error "SCXRD Dataset #{id}: Error parsing image metadata: #{e.message}"
      {
        success: false,
        error: e.message,
        dimensions: [ 0, 0 ],
        pixel_size: [ 0.0, 0.0 ],
        metadata: {}
      }
    end
  end

  def parsed_image_data(force_refresh: false, diffraction_image: nil)
    return @parsed_image_data if @parsed_image_data && !force_refresh && diffraction_image.nil?

    # Determine which image to parse
    image_source = diffraction_image&.rodhypix_file || diffraction_images.order(:run_number, :image_number).first&.rodhypix_file
    return nil unless image_source&.attached?

    begin
      # Download the image data
      image_data = image_source.blob.download

      # Parse using the ROD parser service
      parser = RodImageParserService.new(image_data)
      parsed_data = parser.parse

      # Cache only if parsing the default first image
      @parsed_image_data = parsed_data if diffraction_image.nil?

      parsed_data
    rescue => e
      Rails.logger.error "SCXRD Dataset #{id}: Error parsing image data: #{e.message}"
      {
        success: false,
        error: e.message,
        dimensions: [ 0, 0 ],
        pixel_size: [ 0.0, 0.0 ],
        image_data: [],
        metadata: {}
      }
    end
  end

  def image_dimensions
    parsed_data = parsed_image_data
    parsed_data[:dimensions] if parsed_data[:success]
  end

  def image_pixel_size
    parsed_data = parsed_image_data
    parsed_data[:pixel_size] if parsed_data[:success]
  end

  def image_metadata
    parsed_data = parsed_image_data
    parsed_data[:metadata] if parsed_data[:success]
  end

  def has_valid_image_data?(diffraction_image: nil)
    return false unless diffraction_image&.rodhypix_file&.attached? || diffraction_images.any?
    parsed_data = parsed_image_data(diffraction_image: diffraction_image)
    parsed_data[:success] && !parsed_data[:image_data].empty?
  end

  def parsed_peak_table_data(force_refresh: false)
    return @parsed_peak_table_data if @parsed_peak_table_data && !force_refresh
    return nil unless has_peak_table?

    begin
      # Download the peak table data
      peak_data = peak_table.blob.download

      # Parse using the peak table parser service
      parser = PeakTableParserService.new(peak_data)
      @parsed_peak_table_data = parser.parse

      # Enrich data points with indexing information if UB matrix is available
      if @parsed_peak_table_data[:success] && has_ub_matrix?
        enrich_with_indexing_info!(@parsed_peak_table_data)
      end

      @parsed_peak_table_data
    rescue => e
      Rails.logger.error "SCXRD Dataset #{id}: Error parsing peak table data: #{e.message}"
      {
        success: false,
        error: e.message,
        data_points: [],
        statistics: {}
      }
    end
  end

  def has_valid_peak_table_data?
    return false unless has_peak_table?
    parsed_data = parsed_peak_table_data
    parsed_data[:success] && !parsed_data[:data_points].empty?
  end

  private

  # Enrich parsed peak table data with indexing information
  # Adds an :indexed boolean to each data point
  def enrich_with_indexing_info!(parsed_data, tolerance: 0.125)
    return unless parsed_data[:success] && parsed_data[:data_points].present?

    # Get UB matrix as array
    ub_matrix = ub_matrix_as_array
    return unless ub_matrix

    # Use SpotIndexingService to enrich the data points
    success = SpotIndexingService.enrich_with_indexing_info!(
      parsed_data[:data_points],
      ub_matrix,
      tolerance: tolerance
    )

    unless success
      Rails.logger.error "SCXRD Dataset #{id}: Failed to enrich peak table data with indexing info"
    end
  end

  public

  # Calculate and update spots_found from peak table
  def calculate_spots_found!
    parsed_data = parsed_peak_table_data
    if parsed_data[:success] && parsed_data[:spots_found]
      update_column(:spots_found, parsed_data[:spots_found])
      parsed_data[:spots_found]
    else
      nil
    end
  end

  # Calculate and update spots_indexed using UB matrix
  def calculate_spots_indexed!(tolerance: 0.125)
    return nil unless has_ub_matrix?
    
    parsed_data = parsed_peak_table_data
    return nil unless parsed_data[:success] && parsed_data[:data_points].present?

    # Get UB matrix as array
    ub_matrix = ub_matrix_as_array
    
    # Calculate indexed spots
    result = SpotIndexingService.calculate_indexed_spots(
      parsed_data[:data_points],
      ub_matrix,
      tolerance: tolerance
    )
    
    if result[:indexed_count]
      update_column(:spots_indexed, result[:indexed_count])
      result[:indexed_count]
    else
      nil
    end
  end

  # Calculate both spots_found and spots_indexed in one operation
  def calculate_spot_statistics!(tolerance: 0.125)
    spots_found = calculate_spots_found!
    spots_indexed = calculate_spots_indexed!(tolerance: tolerance)
    
    {
      spots_found: spots_found,
      spots_indexed: spots_indexed,
      indexing_rate: (spots_found && spots_indexed && spots_found > 0) ? 
                      (spots_indexed.to_f / spots_found * 100).round(2) : nil
    }
  end

  # UB matrix methods
  def has_ub_matrix?
    ub11.present? && ub12.present? && ub13.present? &&
    ub21.present? && ub22.present? && ub23.present? &&
    ub31.present? && ub32.present? && ub33.present?
  end

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

  # Unit cell conversion methods
  def has_primitive_cell?
    primitive_a.present? && primitive_b.present? && primitive_c.present? &&
    primitive_alpha.present? && primitive_beta.present? && primitive_gamma.present?
  end

  def has_conventional_cell?
    conventional_a.present? && conventional_b.present? && conventional_c.present? &&
    conventional_alpha.present? && conventional_beta.present? && conventional_gamma.present?
  end

  def conventional_cells
    return [] unless has_primitive_cell?

    @conventional_cells ||= ConventionalCellService.convert_to_conventional(
      primitive_a, primitive_b, primitive_c,
      primitive_alpha, primitive_beta, primitive_gamma
    ) || []
  end

  def best_conventional_cell
    return nil unless has_primitive_cell?

    @best_conventional_cell ||= ConventionalCellService.best_conventional_cell(
      primitive_a, primitive_b, primitive_c,
      primitive_alpha, primitive_beta, primitive_gamma
    )
  end

  def conventional_cell_as_input
    return nil unless has_primitive_cell?

    @conventional_cell_as_input ||= ConventionalCellService.conventional_cell_as_input(
      primitive_a, primitive_b, primitive_c,
      primitive_alpha, primitive_beta, primitive_gamma
    )
  end


  # Get conventional cell for display (prefers stored conventional cell, falls back to API or primitive)
  def display_cell
    # First priority: use stored conventional cell if available
    if has_conventional_cell?
      return {
        bravais: conventional_bravais || "unknown",
        a: conventional_a,
        b: conventional_b,
        c: conventional_c,
        alpha: conventional_alpha,
        beta: conventional_beta,
        gamma: conventional_gamma,
        distance: conventional_distance || 0
      }
    end

    # Second priority: try API conversion
    conventional = best_conventional_cell
    return conventional if conventional

    # Fallback to primitive cell
    return nil unless has_primitive_cell?

    {
      bravais: "aP",  # Primitive triclinic as fallback
      a: primitive_a,
      b: primitive_b,
      c: primitive_c,
      alpha: primitive_alpha,
      beta: primitive_beta,
      gamma: primitive_gamma,
      distance: 0
    }
  end

  # Unit cell similarity methods using G6 distance API
  def g6_distance_to(other_dataset)
    return nil unless has_primitive_cell? && other_dataset.has_primitive_cell?

    G6DistanceService.calculate_distance_between_datasets(self, other_dataset)
  end

  def similar_datasets_by_g6(tolerance: 10.0)
    # Use precomputed similarities for much faster lookup
    similar_datasets(tolerance: tolerance)
  end

  def similar_datasets_count_by_g6(tolerance: 10.0)
    similar_datasets_by_g6(tolerance: tolerance).size
  end

  # Extract cell parameters for G6 calculations
  def extract_cell_params_for_g6
    # Use conventional cell if available, fallback to primitive
    conventional_cell_as_input || {
      a: primitive_a,
      b: primitive_b,
      c: primitive_c,
      alpha: primitive_alpha,
      beta: primitive_beta,
      gamma: primitive_gamma
    }
  end

  # Get all chemical formulas associated with this dataset's well
  # Returns array of empirical formulas from both direct chemicals and stock solution components
  def associated_chemical_formulas
    return [] unless well.present?
    
    begin
      formulas = []
      
      # Get formulas from direct chemicals in the well
      well.chemicals.each do |chemical|
        if chemical.empirical_formula.present?
          formulas << chemical.empirical_formula
        end
      end
      
      # Get formulas from stock solution components  
      well.polymorphic_stock_solutions.each do |stock_solution|
        stock_solution.chemicals.each do |chemical|
          if chemical.empirical_formula.present?
            formulas << chemical.empirical_formula
          end
        end
      end
      
      # Remove duplicates and blanks
      formulas.compact.uniq.reject(&:blank?)
    rescue StandardError => e
      Rails.logger.error "Error retrieving chemical formulas for SCXRD dataset #{id}: #{e.message}"
      []
    end
  end

  # Check if any of the associated formulas match a given CSD formula
  def formula_matches_well_contents?(csd_formula, tolerance_percent: 10.0)
    return false if csd_formula.blank?
    
    well_formulas = associated_chemical_formulas
    return false if well_formulas.empty?
    
    well_formulas.any? do |well_formula|
      FormulaComparisonService.formulas_match?(csd_formula, well_formula, tolerance_percent: tolerance_percent)
    end
  end

  # Unit cell similarity methods
  def unit_cell_similarities
    UnitCellSimilarity.for_dataset(id)
  end

  def similar_datasets(tolerance: 10.0)
    similarities = unit_cell_similarities.within_tolerance(tolerance).includes(:dataset_1, :dataset_2)
    similarities.map { |sim| sim.other_dataset(id) }.compact
  end

  # Get all similarities for this dataset as a hash for easy lookup
  def similarities_hash
    similarities = {}
    unit_cell_similarities.includes(:dataset_1, :dataset_2).each do |sim|
      other_dataset = sim.other_dataset(id)
      similarities[other_dataset.id] = sim.g6_distance if other_dataset
    end
    similarities
  end

  private

  # Check if primitive cell parameters have changed
  def saved_change_to_primitive_cell?
    saved_change_to_primitive_a? || saved_change_to_primitive_b? || saved_change_to_primitive_c? ||
    saved_change_to_primitive_alpha? || saved_change_to_primitive_beta? || saved_change_to_primitive_gamma?
  end

  # Trigger similarity computation in background
  def compute_unit_cell_similarities
    UnitCellSimilarityComputationService.perform_later(self)
  end

  # Get best matching formula from well contents for a given CSD formula
  def best_matching_formula(csd_formula, tolerance_percent: 10.0)
    return nil if csd_formula.blank?
    
    well_formulas = associated_chemical_formulas
    return nil if well_formulas.empty?
    
    matches = FormulaComparisonService.find_matching_formulas(csd_formula, well_formulas, tolerance_percent: tolerance_percent)
    matches.first&.dig(:formula)
  end
end
