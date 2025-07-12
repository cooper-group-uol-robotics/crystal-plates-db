class Location < ApplicationRecord
  has_many :plate_locations, dependent: :destroy
  has_many :plates, through: :plate_locations

  # Method to get plates currently at this location using the new scope
  def current_plates
    Plate.joins(:plate_locations)
         .merge(PlateLocation.most_recent_for_each_plate)
         .where(plate_locations: { location_id: id })
  end

  # Method to get current plate locations for this location
  def current_plate_locations
    # Find plates whose most recent location is this location
    current_plate_ids = current_plates.pluck(:id)

    # Get the most recent plate_location record for each of those plates at this location
    PlateLocation.where(plate_id: current_plate_ids, location_id: id)
                 .where(
                   id: PlateLocation.where(plate_id: current_plate_ids)
                                   .select("MAX(id)")
                                   .group(:plate_id)
                 )
  end

  # Scope to efficiently load occupation status - simplified since we're using methods
  scope :with_occupation_status, -> { all }

  # Scope to preload current plate data - simplified since we're using methods
  scope :with_current_plate_data, -> { all }

  validates :carousel_position, numericality: { greater_than: 0 }, allow_nil: true
  validates :hotel_position, numericality: { greater_than: 0 }, allow_nil: true
  validates :name, presence: true, if: -> { carousel_position.nil? && hotel_position.nil? }

  # Ensure either name is present OR both carousel and hotel positions are present
  validate :name_or_positions_present

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
    # Check if there are current plates at this location
    current_plates.any?
  end

  # Get the current plate ID efficiently from preloaded data
  def current_plate_id
    current_plates.first&.id
  end

  # Get the current plate barcode efficiently from preloaded data
  def current_plate_barcode
    current_plates.first&.barcode
  end

  # Check if there's a current plate
  def has_current_plate?
    current_plates.any?
  end

  private

  def name_or_positions_present
    if name.blank? && (carousel_position.blank? || hotel_position.blank?)
      errors.add(:base, "Either name must be present, or both carousel_position and hotel_position must be present")
    end
  end
end
