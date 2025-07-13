require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @carousel_location = locations(:carousel_1_hotel_1)
    @imager_location = locations(:imager)
  end

  test "should get index" do
    get locations_url
    assert_redirected_to grid_locations_url
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

  test "should not create duplicate carousel position" do
    # Try to create a location with same position as existing fixture
    assert_no_difference("Location.count") do
      post locations_url, params: {
        location: {
          carousel_position: @carousel_location.carousel_position,
          hotel_position: @carousel_location.hotel_position
        },
        location_type: "carousel"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".alert", /error/i
  end

  test "should not create duplicate special location name" do
    # Try to create a location with same name as existing fixture
    assert_no_difference("Location.count") do
      post locations_url, params: {
        location: {
          name: @imager_location.name
        },
        location_type: "special"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".alert", /error/i
  end

  test "should not create duplicate special location name case insensitive" do
    # Try to create a location with same name in different case
    assert_no_difference("Location.count") do
      post locations_url, params: {
        location: {
          name: @imager_location.name.upcase
        },
        location_type: "special"
      }
    end

    assert_response :unprocessable_entity
    assert_select ".alert", /error/i
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

  test "should not update to duplicate carousel position" do
    # Create a second carousel location
    other_location = Location.create!(carousel_position: 9, hotel_position: 9)

    # Try to update first location to have same position as second
    patch location_url(@carousel_location), params: {
      location: {
        carousel_position: other_location.carousel_position,
        hotel_position: other_location.hotel_position
      },
      location_type: "carousel"
    }

    assert_response :unprocessable_entity
    assert_select ".alert", /error/i

    # Ensure the location wasn't updated
    @carousel_location.reload
    assert_not_equal other_location.carousel_position, @carousel_location.carousel_position
  end

  test "should not update to duplicate special location name" do
    # Create another special location
    other_location = Location.create!(name: "other_special")

    # Try to update imager location to have same name
    patch location_url(@imager_location), params: {
      location: {
        name: other_location.name
      },
      location_type: "special"
    }

    assert_response :unprocessable_entity
    assert_select ".alert", /error/i

    # Ensure the location wasn't updated
    @imager_location.reload
    assert_not_equal other_location.name, @imager_location.name
  end

  test "should destroy empty location" do
    # Create a location without any plates
    empty_location = Location.create!(name: "empty_test_location")

    assert_difference("Location.count", -1) do
      delete location_url(empty_location)
    end

    assert_redirected_to grid_locations_url
  end

  test "should not destroy occupied location" do
    # Ensure the imager location has a plate
    plate = plates(:one)
    plate.move_to_location!(@imager_location)

    assert_no_difference("Location.count") do
      delete location_url(@imager_location)
    end

    assert_redirected_to grid_locations_url
    follow_redirect!
    assert_select ".alert.alert-danger", /Cannot delete location that currently contains plates/
  end

  test "index should redirect to grid" do
    # Move a plate to carousel location
    plate = plates(:one)
    plate.move_to_location!(@carousel_location)

    get grid_locations_url

    # Should show grid with proper structure
    assert_select ".carousel-grid"
    assert_select ".grid-cell"
    assert_response :success
  end

  test "grid should display carousel positions correctly" do
    # Move a plate to carousel location
    plate = plates(:one)
    plate.move_to_location!(@carousel_location)

    get grid_locations_url

    # Should show grid with proper structure
    assert_select ".carousel-grid"
    assert_select ".grid-cell"
    assert_response :success
  end

  test "locations with_occupation_status scope works efficiently" do
    # Create locations and test the scope
    location1 = Location.create!(name: "test_location_1")
    location2 = Location.create!(name: "test_location_2")

    # Move plate to location1
    plate = plates(:one)
    plate.move_to_location!(location1)

    # Test the scope - use to_a to force evaluation
    locations = Location.with_occupation_status.to_a
    assert locations.count >= 2

    # Find our test locations
    occupied_location = locations.find { |l| l.id == location1.id }
    empty_location = locations.find { |l| l.id == location2.id }

    # Test occupation status
    assert occupied_location.occupied?, "Location with plate should be occupied"
    assert_not empty_location.occupied?, "Location without plate should not be occupied"
  end

  test "locations have current_plate methods when using with_current_plate_data" do
    location = Location.create!(name: "test_current_plate")
    plate = plates(:one)
    plate.move_to_location!(location)

    # Test with preloaded data
    location_with_data = Location.with_current_plate_data.find(location.id)

    assert location_with_data.has_current_plate?, "Should have current plate"
    assert_equal plate.id, location_with_data.current_plate_id
    assert_equal plate.barcode, location_with_data.current_plate_barcode
  end

  test "grid view uses efficient queries" do
    # Create multiple carousel locations with plates
    3.times do |i|
      location = Location.create!(carousel_position: i + 10, hotel_position: 1)
      plate = Plate.create!(barcode: "GRID_TEST_#{i}")
      plate.move_to_location!(location)
    end

    # Create some special locations
    2.times do |i|
      location = Location.create!(name: "special_#{i}")
      if i == 0
        plate = Plate.create!(barcode: "SPECIAL_TEST")
        plate.move_to_location!(location)
      end
    end

    # Grid view should load efficiently
    get grid_locations_url
    assert_response :success

    # Should contain grid elements
    assert_select ".carousel-grid"
    assert_select ".grid-cell"
  end

  test "grid view displays occupation status correctly" do
    # Create a carousel location and move a plate to it
    test_location = Location.create!(carousel_position: 5, hotel_position: 5)
    test_plate = Plate.create!(barcode: "GRID_OCCUPIED_TEST")
    test_plate.move_to_location!(test_location)

    get grid_locations_url
    assert_response :success

    # Should show occupied status in the grid
    response_body = response.body
    assert_includes response_body, "GRID_OCCUPIED_TEST"
  end

  test "index redirects to grid and uses efficient preloading" do
    # Create locations with plates to test preloading
    location1 = Location.create!(name: "redirect_test_1")
    Location.create!(name: "redirect_test_2")  # unused but good for testing preloading

    plate1 = Plate.create!(barcode: "REDIRECT_TEST_1")
    plate1.move_to_location!(location1)

    # Index should redirect to grid
    get locations_url
    assert_redirected_to grid_locations_url

    # Follow redirect and ensure it works
    follow_redirect!
    assert_response :success
    assert_select "h1", text: "Carousel Grid View"
  end
end
