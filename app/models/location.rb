class Location < ApplicationRecord
  has_many :plate_locations, dependent: :destroy
  has_many :plates, through: :plate_locations

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

  private

  def name_or_positions_present
    if name.blank? && (carousel_position.blank? || hotel_position.blank?)
      errors.add(:base, "Either name must be present, or both carousel_position and hotel_position must be present")
    end
  end
end
