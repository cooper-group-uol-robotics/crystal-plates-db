class ScxrdDataset < ApplicationRecord
  belongs_to :well
  has_one_attached :archive
  has_one_attached :peak_table
  has_one_attached :first_image

  validates :experiment_name, :date_measured, presence: true
  validates :niggli_a, :niggli_b, :niggli_c, :niggli_alpha, :niggli_beta, :niggli_gamma, numericality: { greater_than: 0 }, allow_nil: true
  validates :real_world_x_mm, :real_world_y_mm, :real_world_z_mm, numericality: true, allow_nil: true

  # Scopes
  scope :with_coordinates, -> { where.not(real_world_x_mm: nil, real_world_y_mm: nil) }
  scope :near_coordinates, ->(x_mm, y_mm, tolerance_mm = 0.5) {
    with_coordinates.where(
      "(ABS(real_world_x_mm - ?) + ABS(real_world_y_mm - ?)) <= ?",
      x_mm, y_mm, tolerance_mm * 1.4142 # Manhattan distance approximation
    )
  }

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

  def has_first_image?
    first_image.attached?
  end

  def peak_table_size
    return 0 unless peak_table.attached?
    peak_table.blob.byte_size
  end

  def first_image_size
    return 0 unless first_image.attached?
    first_image.blob.byte_size
  end

  def parsed_image_data(force_refresh: false)
    return @parsed_image_data if @parsed_image_data && !force_refresh
    return nil unless has_first_image?

    begin
      # Download the image data
      image_data = first_image.blob.download

      # Parse using the ROD parser service
      parser = RodImageParserService.new(image_data)
      @parsed_image_data = parser.parse

      @parsed_image_data
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

  def has_valid_image_data?
    return false unless has_first_image?
    parsed_data = parsed_image_data
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
end
