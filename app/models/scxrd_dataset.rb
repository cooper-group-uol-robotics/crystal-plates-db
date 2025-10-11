class ScxrdDataset < ApplicationRecord
  belongs_to :well, optional: true
  has_many :diffraction_images, dependent: :destroy
  has_one_attached :archive
  has_one_attached :peak_table
  has_one_attached :crystal_image
  has_one_attached :structure_file


  validates :experiment_name, :measured_at, presence: true
  validates :primitive_a, :primitive_b, :primitive_c, :primitive_alpha, :primitive_beta, :primitive_gamma, numericality: { greater_than: 0 }, allow_nil: true
  validates :real_world_x_mm, :real_world_y_mm, :real_world_z_mm, numericality: true, allow_nil: true

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

  # Unit cell conversion methods
  def has_primitive_cell?
    primitive_a.present? && primitive_b.present? && primitive_c.present? &&
    primitive_alpha.present? && primitive_beta.present? && primitive_gamma.present?
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


  # Get conventional cell for display (falls back to primitive if conversion fails)
  def display_cell
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
    return ScxrdDataset.none unless has_primitive_cell?

    # Get all other datasets with primitive cells
    candidates = ScxrdDataset.where.not(id: id).includes(:well)
                             .where.not(primitive_a: nil, primitive_b: nil, primitive_c: nil,
                                       primitive_alpha: nil, primitive_beta: nil, primitive_gamma: nil)

    G6DistanceService.find_similar_datasets(self, candidates, tolerance: tolerance)
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
end
