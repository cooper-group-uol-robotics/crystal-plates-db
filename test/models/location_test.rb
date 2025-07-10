require "test_helper"

class LocationTest < ActiveSupport::TestCase
  setup do
    @carousel_location = locations(:carousel_1_hotel_1)
    @imager_location = locations(:imager)
    @plate1 = plates(:one)
  end

  test "should create valid carousel location" do
    location = Location.new(carousel_position: 3, hotel_position: 5)
    assert location.valid?
    assert location.save
  end

  test "should create valid special location" do
    location = Location.new(name: "storage_room")
    assert location.valid?
    assert location.save
  end

  test "should not create location without name or positions" do
    location = Location.new
    assert_not location.valid?
    assert_includes location.errors[:base], "Either name must be present, or both carousel_position and hotel_position must be present"
  end

  test "should not create location with only carousel position" do
    location = Location.new(carousel_position: 3)
    assert_not location.valid?
    assert_includes location.errors[:base], "Either name must be present, or both carousel_position and hotel_position must be present"
  end

  test "should not create location with only hotel position" do
    location = Location.new(hotel_position: 5)
    assert_not location.valid?
    assert_includes location.errors[:base], "Either name must be present, or both carousel_position and hotel_position must be present"
  end

  test "should not create location with negative carousel position" do
    location = Location.new(carousel_position: -1, hotel_position: 5)
    assert_not location.valid?
    assert_includes location.errors[:carousel_position], "must be greater than 0"
  end

  test "should not create location with negative hotel position" do
    location = Location.new(carousel_position: 3, hotel_position: -1)
    assert_not location.valid?
    assert_includes location.errors[:hotel_position], "must be greater than 0"
  end

  test "should not create location with zero carousel position" do
    location = Location.new(carousel_position: 0, hotel_position: 5)
    assert_not location.valid?
    assert_includes location.errors[:carousel_position], "must be greater than 0"
  end

  test "should not create location with zero hotel position" do
    location = Location.new(carousel_position: 3, hotel_position: 0)
    assert_not location.valid?
    assert_includes location.errors[:hotel_position], "must be greater than 0"
  end

  test "should allow name with nil carousel and hotel positions" do
    location = Location.new(name: "test_location", carousel_position: nil, hotel_position: nil)
    assert location.valid?
  end

  test "should allow both name and positions (though not typical)" do
    location = Location.new(name: "test_location", carousel_position: 3, hotel_position: 5)
    assert location.valid?
  end

  test "display_name should return name for special locations" do
    assert_equal "imager", @imager_location.display_name
  end

  test "display_name should return formatted string for carousel locations" do
    assert_equal "Carousel 1, Hotel 1", @carousel_location.display_name
  end

  test "display_name should return fallback for incomplete location" do
    location = Location.create!(name: "test")
    location.update_column(:name, nil) # Bypass validation to test fallback
    assert_equal "Location ##{location.id}", location.display_name
  end

  test "should have many plate_locations" do
    assert_respond_to @carousel_location, :plate_locations
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @carousel_location.plate_locations
  end

  test "should have many plates through plate_locations" do
    assert_respond_to @carousel_location, :plates
    assert_kind_of ActiveRecord::Associations::CollectionProxy, @carousel_location.plates
  end

  test "should destroy dependent plate_locations when location is destroyed" do
    # Move a plate to the location
    @plate1.move_to_location!(@carousel_location, moved_by: "test")

    plate_location_id = @plate1.plate_locations.first.id

    # Destroy the location
    @carousel_location.destroy

    # Check that the plate_location was also destroyed
    assert_raises(ActiveRecord::RecordNotFound) do
      PlateLocation.find(plate_location_id)
    end
  end

  test "should allow creation of duplicate carousel/hotel combinations" do
    # This tests that we don't have uniqueness constraints (in case multiple plates
    # have been in the same location at different times)
    location1 = Location.create!(carousel_position: 5, hotel_position: 10)
    location2 = Location.create!(carousel_position: 5, hotel_position: 10)

    assert location1.persisted?
    assert location2.persisted?
    assert_not_equal location1.id, location2.id
  end

  test "should allow creation of duplicate names" do
    location1 = Location.create!(name: "storage")
    location2 = Location.create!(name: "storage")

    assert location1.persisted?
    assert location2.persisted?
    assert_not_equal location1.id, location2.id
  end
end
