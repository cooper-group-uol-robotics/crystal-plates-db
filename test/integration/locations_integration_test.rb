require "test_helper"

class LocationsIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @carousel_location = locations(:carousel_1_hotel_1)
    @imager_location = locations(:imager)
    @plate1 = plates(:one)
    @plate2 = plates(:two)
  end

  test "location index shows all locations with status" do
    # Move a plate to carousel location
    @plate1.move_to_location!(@carousel_location)
    # Move another plate to a special location to test status display
    @plate2.move_to_location!(@imager_location)

    get grid_locations_path
    assert_response :success

    # Check for carousel locations section
    assert_select "h5", text: "Carousel Locations"
    assert_select ".carousel-grid"

    # Check for special locations section
    assert_select "h6", text: "Special Locations"

    # Check for occupied status (plate barcode should be shown)
    assert_select ".text-warning", text: @plate2.barcode
  end

  test "location show displays complete information" do
    # Move plate to location
    @plate1.move_to_location!(@carousel_location)

    get location_path(@carousel_location)
    assert_response :success

    # Check location details
    assert_select "h1", text: "Location: Carousel 1, Hotel 1"
    assert_select "strong", text: "Carousel:"
    assert_select "strong", text: "Hotel Position:"

    # Check current plates section
    assert_select "h5", text: "Current Plates"
    assert_select "strong", text: @plate1.barcode

    # Check history section
    assert_select "h5", text: "Recent Movement History"
    assert_select "table"
  end

  test "grid view displays carousel positions correctly" do
    # Create some additional locations for testing
    Location.create!(carousel_position: 2, hotel_position: 1)
    Location.create!(carousel_position: 2, hotel_position: 2)

    # Move plates to different locations
    @plate1.move_to_location!(@carousel_location)
    @plate2.move_to_location!(locations(:carousel_1_hotel_2))

    get grid_locations_path
    assert_response :success

    # Check grid structure
    assert_select "h1", text: "Carousel Grid View"
    assert_select ".carousel-grid"
    assert_select ".grid-cell"

    # Check for occupied and available cells
    assert_select ".grid-cell.occupied"
    assert_select ".grid-cell.available"
  end

  test "location creation workflow" do
    # Test carousel location creation
    assert_difference "Location.count", 1 do
      post locations_path, params: {
        location: {
          carousel_position: 5,
          hotel_position: 10
        },
        location_type: "carousel"
      }
    end

    new_location = Location.last
    assert_equal 5, new_location.carousel_position
    assert_equal 10, new_location.hotel_position
    assert_nil new_location.name

    assert_redirected_to location_path(new_location)
    follow_redirect!
    assert_select "h1", text: "Location: Carousel 5, Hotel 10"
  end

  test "special location creation workflow" do
    # Test special location creation
    assert_difference "Location.count", 1 do
      post locations_path, params: {
        location: {
          name: "test_storage_room"
        },
        location_type: "special"
      }
    end

    new_location = Location.last
    assert_equal "test_storage_room", new_location.name
    assert_nil new_location.carousel_position
    assert_nil new_location.hotel_position

    assert_redirected_to location_path(new_location)
    follow_redirect!
    assert_select "h1", text: "Location: test_storage_room"
  end

  test "location update workflow" do
    patch location_path(@carousel_location), params: {
      location: {
        carousel_position: 8,
        hotel_position: 12
      },
      location_type: "carousel"
    }

    assert_redirected_to location_path(@carousel_location)

    @carousel_location.reload
    assert_equal 8, @carousel_location.carousel_position
    assert_equal 12, @carousel_location.hotel_position

    follow_redirect!
    assert_select "h1", text: "Location: Carousel 8, Hotel 12"
  end

  test "location deletion workflow" do
    # Create a location without plates
    empty_location = Location.create!(name: "empty_integration_test")

    assert_difference "Location.count", -1 do
      delete location_path(empty_location)
    end

    assert_redirected_to grid_locations_path
    follow_redirect!
    assert_select ".alert-success", text: "Location was successfully deleted."
  end

  test "cannot delete occupied location" do
    # Move plate to location
    @plate1.move_to_location!(@imager_location)

    assert_no_difference "Location.count" do
      delete location_path(@imager_location)
    end

    assert_redirected_to grid_locations_path
    follow_redirect!
    assert_select ".alert-danger", text: "Cannot delete location that currently contains plates."
  end

  test "location validation errors are displayed" do
    # Try to create invalid location
    post locations_path, params: {
      location: {
        carousel_position: -1,
        hotel_position: 5
      },
      location_type: "carousel"
    }

    assert_response :unprocessable_entity
    assert_select ".alert-danger"
    assert_select "h1", text: "Create New Location"
  end

  test "location update validation errors are displayed" do
    # Try to update with invalid data
    patch location_path(@carousel_location), params: {
      location: {
        carousel_position: 0,
        hotel_position: -1
      },
      location_type: "carousel"
    }

    assert_response :unprocessable_entity
    assert_select ".alert-danger"
    assert_select "h1", text: "Edit Location"
  end

  test "location search and filtering" do
    # Create some additional locations for testing
    Location.create!(name: "storage")
    Location.create!(name: "freezer")

    get grid_locations_path
    assert_response :success

    # Should show all location types
    assert_select ".grid-header-cell", text: "C1"  # Carousel position header
    assert_select ".fw-bold.small", text: "imager"  # Special locations are shown in special-location-card
    assert_select ".fw-bold.small", text: "storage"
    assert_select ".fw-bold.small", text: "freezer"
  end
end
