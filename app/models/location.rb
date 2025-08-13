class Location < ApplicationRecord
  has_many :plate_locations, dependent: :destroy
  has_many :plates, through: :plate_locations

  # Method to get plates currently at this location using the new scope
  def current_plates
    # Use cached data if available (set by controller to avoid N+1)
    if instance_variable_defined?(:@cached_current_plate)
      cached_plate = instance_variable_get(:@cached_current_plate)
      return cached_plate ? [ cached_plate ] : []
    end

    # Use ActiveRecord with subquery to find latest locations for this location
    latest_location_ids = PlateLocation
      .select("MAX(id)")
      .group(:plate_id)

    current_plate_location_ids = PlateLocation
      .where(location_id: id)
      .where("id IN (#{latest_location_ids.to_sql})")
      .pluck(:plate_id)

    Plate.where(id: current_plate_location_ids)
  end

  # Method to get current plate locations for this location
  def current_plate_locations
    # Use the same logic as current_plates but return the plate_locations
    latest_location_ids = PlateLocation
      .select("MAX(id)")
      .group(:plate_id)

    PlateLocation.where(location_id: id)
                 .where("id IN (#{latest_location_ids.to_sql})")
  end

  # Scope to efficiently load occupation status with optimized query
  scope :with_occupation_status, -> {
    # Use a subquery to find latest plate locations without window functions in WHERE
    latest_plate_location_ids = PlateLocation
      .select("MAX(id) as latest_id")
      .group(:plate_id)

    current_plate_locations = PlateLocation
      .joins("INNER JOIN (#{latest_plate_location_ids.to_sql}) latest ON plate_locations.id = latest.latest_id")
      .select(:location_id, :plate_id)

    joins("LEFT JOIN (#{current_plate_locations.to_sql}) current_locations ON locations.id = current_locations.location_id")
      .select("locations.*, current_locations.plate_id as current_plate_id")
  }

  # Scope to preload current plate data efficiently
  scope :with_current_plate_data, -> {
    # Use the same efficient query as with_occupation_status
    latest_plate_location_ids = PlateLocation
      .select("MAX(id) as latest_id")
      .group(:plate_id)

    current_plate_locations = PlateLocation
      .joins("INNER JOIN (#{latest_plate_location_ids.to_sql}) latest ON plate_locations.id = latest.latest_id")
      .select(:location_id, :plate_id)

    joins("LEFT JOIN (#{current_plate_locations.to_sql}) current_locations ON locations.id = current_locations.location_id")
      .select("locations.*, current_locations.plate_id as current_plate_id")
  }

  validates :carousel_position, numericality: { greater_than: 0 }, allow_nil: true
  validates :hotel_position, numericality: { greater_than: 0 }, allow_nil: true
  validates :name, presence: true, if: -> { carousel_position.nil? && hotel_position.nil? }
  validates :name, uniqueness: { case_sensitive: false }, if: -> { name.present? && carousel_position.nil? && hotel_position.nil? }

  # Ensure uniqueness of carousel position and hotel position combination
  validates :carousel_position, uniqueness: { scope: :hotel_position }, if: -> { carousel_position.present? && hotel_position.present? }

  # Ensure either name is present OR both carousel and hotel positions are present
  validate :name_or_positions_present

  # Class method for efficiently bulk loading location occupation data
  def self.with_current_occupation_data
    # Use a more SQLite-friendly approach without window functions in WHERE clauses
    latest_plate_location_ids = PlateLocation
      .select("MAX(id) as latest_id")
      .group(:plate_id)

    current_plate_locations = PlateLocation
      .joins("INNER JOIN (#{latest_plate_location_ids.to_sql}) latest ON plate_locations.id = latest.latest_id")
      .joins(:plate)
      .select("plate_locations.location_id, plates.id as plate_id, plates.barcode as plate_barcode, plates.name as plate_name")

    query = Location
      .joins("LEFT JOIN (#{current_plate_locations.to_sql}) current_plates ON locations.id = current_plates.location_id")
      .select("locations.*, current_plates.plate_id as current_plate_id, current_plates.plate_barcode as current_plate_barcode, current_plates.plate_name as current_plate_name")
      .order(:id)

    query.map do |location|
      # Cache the current plate data to avoid N+1 queries
      if location.try(:current_plate_id)
        current_plate = Plate.new(
          id: location.current_plate_id,
          barcode: location.current_plate_barcode,
          name: location.current_plate_name
        )
        location.instance_variable_set(:@cached_current_plate, current_plate)
        location.instance_variable_set(:@cached_has_current_plate, true)
      else
        location.instance_variable_set(:@cached_current_plate, nil)
        location.instance_variable_set(:@cached_has_current_plate, false)
      end

      location
    end
  end

  def display_name
    if name.present?
      name
    elsif carousel_position.present? && hotel_position.present?
      "Carousel #{carousel_position}, Hotel #{hotel_position}"
    else
      "Location ##{id}"
    end
  end

  def occupied?
    # Use virtual attribute if available (from with_occupation_status scope)
    if attributes.key?("current_plate_id")
      return attributes["current_plate_id"].present?
    end

    # Check if there are current plates at this location
    current_plates.any?
  end

  # Get the current plate ID efficiently from preloaded data
  def current_plate_id
    # Check if we have a virtual attribute from a scope (like with_occupation_status)
    if attributes.key?("current_plate_id")
      return attributes["current_plate_id"]
    end

    # Fall back to querying current_plates
    current_plates.first&.id
  end

  # Get the current plate barcode efficiently from preloaded data
  def current_plate_barcode
    current_plates.first&.barcode
  end

  # Check if there's a current plate
  def has_current_plate?
    # Use cached data if available
    if instance_variable_defined?(:@cached_has_current_plate)
      return instance_variable_get(:@cached_has_current_plate)
    end

    # Fallback to database query
    current_plates.any?
  end

  private

  def name_or_positions_present
    if name.blank? && (carousel_position.blank? || hotel_position.blank?)
      errors.add(:base, "Either name must be present, or both carousel_position and hotel_position must be present")
    end
  end
end
