require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @carousel_location = locations(:carousel_1_hotel_1)
    @imager_location = locations(:imager)
  end

  test "should get index" do
    get locations_url
    assert_response :success
    assert_select "h1", "Location Management"
  end

  test "should get grid" do
    get grid_locations_url
    assert_response :success
    assert_select "h1", "Carousel Grid View"
  end

  test "should show location" do
    get location_url(@carousel_location)
    assert_response :success
    assert_select "h1", /Location:/
  end

  test "should get new" do
    get new_location_url
    assert_response :success
    assert_select "h1", "Create New Location"
  end

  test "should create carousel location" do
    assert_difference("Location.count") do
      post locations_url, params: {
        location: {
          carousel_position: 5,
          hotel_position: 15
        },
        location_type: "carousel"
      }
    end

    location = Location.last
    assert_equal 5, location.carousel_position
    assert_equal 15, location.hotel_position
    assert_nil location.name
    assert_redirected_to location_url(location)
  end

  test "should create special location" do
    assert_difference("Location.count") do
      post locations_url, params: {
        location: {
          name: "storage_room"
        },
        location_type: "special"
      }
    end

    location = Location.last
    assert_equal "storage_room", location.name
    assert_nil location.carousel_position
    assert_nil location.hotel_position
    assert_redirected_to location_url(location)
  end

  test "should get edit" do
    get edit_location_url(@carousel_location)
    assert_response :success
    assert_select "h1", "Edit Location"
  end

  test "should update location" do
    patch location_url(@carousel_location), params: {
      location: {
        carousel_position: 2,
        hotel_position: 3
      },
      location_type: "carousel"
    }
    assert_redirected_to location_url(@carousel_location)

    @carousel_location.reload
    assert_equal 2, @carousel_location.carousel_position
    assert_equal 3, @carousel_location.hotel_position
  end

  test "should destroy empty location" do
    # Create a location without any plates
    empty_location = Location.create!(name: "empty_test_location")

    assert_difference("Location.count", -1) do
      delete location_url(empty_location)
    end

    assert_redirected_to locations_url
  end

  test "should not destroy occupied location" do
    # Ensure the imager location has a plate
    plate = plates(:one)
    plate.move_to_location!(@imager_location, moved_by: "test")

    assert_no_difference("Location.count") do
      delete location_url(@imager_location)
    end

    assert_redirected_to locations_url
    follow_redirect!
    assert_select ".alert-danger", /Cannot delete location that currently contains plates/
  end

  test "index should show occupied and available locations" do
    # Move a plate to carousel location
    plate = plates(:one)
    plate.move_to_location!(@carousel_location, moved_by: "test")

    get locations_url

    # Should show occupied status
    assert_select "span.badge.bg-warning", "Occupied"
    assert_select "span.badge.bg-success", "Available"
  end

  test "grid should display carousel positions correctly" do
    # Move a plate to carousel location
    plate = plates(:one)
    plate.move_to_location!(@carousel_location, moved_by: "test")

    get grid_locations_url

    # Should show grid with proper structure
    assert_select ".carousel-grid"
    assert_select ".grid-cell"
    assert_response :success
  end
end
