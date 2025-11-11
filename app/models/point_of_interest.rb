class PointOfInterest < ApplicationRecord
  belongs_to :image

  # Validations
  validates :pixel_x, :pixel_y, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :point_type, presence: true, inclusion: { in: %w[crystal particle droplet other measured] }
  validates :marked_at, presence: true

  # Validate coordinates are within image bounds
  validate :coordinates_within_image_bounds

  # Scopes
  scope :crystals, -> { where(point_type: "crystal") }
  scope :particles, -> { where(point_type: "particle") }
  scope :recent, -> { order(marked_at: :desc) }
  scope :by_type, ->(type) { where(point_type: type) }

  # Set default marked_at before validation
  before_validation :set_default_marked_at, on: :create

  # Calculate real-world X coordinate in mm
  def real_world_x_mm
    return nil unless !image&.reference_x_mm.nil? && !image&.pixel_size_x_mm.nil?
    image.reference_x_mm + (pixel_x * image.pixel_size_x_mm)
  end

  # Calculate real-world Y coordinate in mm
  def real_world_y_mm
    return nil unless !image&.reference_y_mm.nil? && !image&.pixel_size_y_mm.nil?
    image.reference_y_mm + (pixel_y * image.pixel_size_y_mm)
  end

  # Get Z coordinate from image (same for all points on the image)
  def real_world_z_mm
    image&.reference_z_mm
  end

  # Get real-world coordinates as a hash
  def real_world_coordinates
    {
      x_mm: real_world_x_mm,
      y_mm: real_world_y_mm,
      z_mm: real_world_z_mm
    }
  end

  # Get pixel coordinates as a hash
  def pixel_coordinates
    {
      x: pixel_x,
      y: pixel_y
    }
  end

  # Get nearby SCXRD datasets within tolerance
  def nearby_scxrd_datasets(tolerance_mm = 0.5)
    coords = real_world_coordinates
    return ScxrdDataset.none unless coords[:x_mm].present? && coords[:y_mm].present?

    # Get all SCXRD datasets from the same well with coordinates
    scxrd_candidates = image.well.scxrd_datasets.where.not(real_world_x_mm: nil, real_world_y_mm: nil)

    # Filter by distance
    scxrd_candidates.select do |dataset|
      distance = dataset.distance_to_coordinates(coords[:x_mm], coords[:y_mm], coords[:z_mm])
      distance.present? && distance <= tolerance_mm
    end
  end

  # Human readable description of the point
  def display_name
    if description.present?
      "#{point_type.humanize}: #{description}"
    else
      "#{point_type.humanize} at (#{pixel_x}, #{pixel_y})"
    end
  end

  private

  def coordinates_within_image_bounds
    return unless image

    if pixel_x && image.pixel_width && pixel_x >= image.pixel_width
      errors.add(:pixel_x, "must be within image width (#{image.pixel_width} pixels)")
    end

    if pixel_y && image.pixel_height && pixel_y >= image.pixel_height
      errors.add(:pixel_y, "must be within image height (#{image.pixel_height} pixels)")
    end
  end

  def set_default_marked_at
    self.marked_at ||= Time.current
  end
end
