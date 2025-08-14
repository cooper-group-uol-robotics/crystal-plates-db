require "test_helper"

class Api::V1::LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @location = locations(:carousel_1_hotel_1)
    @special_location = locations(:imager)
    @plate = plates(:one)
  end

  test "should get index" do
    get api_v1_locations_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")
    assert json_response["data"].is_a?(Array)
  end

  test "should get carousel locations" do
    get carousel_api_v1_locations_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].all? { |loc| loc["carousel_position"] && loc["hotel_position"] }
  end

  test "should get special locations" do
    get special_api_v1_locations_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].all? { |loc| loc["name"] && !loc["carousel_position"] }
  end

  test "should show location" do
    get api_v1_location_url(@location), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")
    assert_equal @location.id, json_response["data"]["id"]
  end

  test "should create carousel location" do
    assert_difference("Location.count") do
      post api_v1_locations_url, params: {
        location: {
          carousel_position: 5,
          hotel_position: 15
        },
        location_type: "carousel"
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal 5, json_response["data"]["carousel_position"]
    assert_equal 15, json_response["data"]["hotel_position"]
  end

  test "should create special location" do
    assert_difference("Location.count") do
      post api_v1_locations_url, params: {
        location: {
          name: "api_storage"
        },
        location_type: "special"
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "api_storage", json_response["data"]["name"]
  end

  test "should update location" do
    patch api_v1_location_url(@location), params: {
      location: {
        carousel_position: 8,
        hotel_position: 12
      },
      location_type: "carousel"
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal 8, json_response["data"]["carousel_position"]
    assert_equal 12, json_response["data"]["hotel_position"]
  end

  test "should destroy empty location" do
    empty_location = Location.create!(name: "api_test_delete")

    assert_difference("Location.count", -1) do
      delete api_v1_location_url(empty_location), as: :json
    end

    assert_response :success
  end

  test "should not destroy occupied location" do
    @plate.move_to_location!(@location)

    assert_no_difference("Location.count") do
      delete api_v1_location_url(@location), as: :json
    end

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
  end

  test "should get current plates" do
    @plate.move_to_location!(@location)

    get current_plates_api_v1_location_url(@location), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].length > 0
    assert json_response["data"].first["barcode"] == @plate.barcode
  end

  test "should get history" do
    @plate.move_to_location!(@location)

    get history_api_v1_location_url(@location), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].is_a?(Array)
  end

  test "should handle validation errors" do
    post api_v1_locations_url, params: {
      location: {
        carousel_position: -1
      }
    }, as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
    assert json_response.key?("details")
  end

  test "should unassign all plates from location" do
    # Create a unique location for this test using timestamp
    unique_pos = Time.current.to_i % 1000
    test_location = Location.create!(carousel_position: unique_pos, hotel_position: unique_pos)
    
    # Create a plate and assign it to the location (since each location can only hold one plate)
    plate = Plate.create!(barcode: "UNASSIGN_TEST_#{unique_pos}")
    plate.move_to_location!(test_location)

    # Verify it is assigned
    assert_equal test_location.id, plate.current_location.id

    # Unassign all plates from the location
    post unassign_all_plates_api_v1_location_url(test_location), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")
    assert_equal 1, json_response["data"]["plates_unassigned"].length
    assert json_response["message"].include?("All plates unassigned successfully")

    # Verify plate is now unassigned
    plate.reload
    assert_nil plate.current_location
  end

  test "should handle unassign all plates from empty location" do
    # Ensure location has no plates
    assert_equal 0, @location.current_plates.count

    post unassign_all_plates_api_v1_location_url(@location), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")
    assert_equal 0, json_response["data"]["plates_unassigned"].length
    assert json_response["message"].include?("No plates to unassign")
  end

  test "should return 404 for unassign all plates on non-existent location" do
    post unassign_all_plates_api_v1_location_url(99999), as: :json
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
    assert json_response["error"].include?("Record not found")
  end
end
