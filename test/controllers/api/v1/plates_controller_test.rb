require "test_helper"

class Api::V1::PlatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @plate = plates(:one)
    @location = locations(:carousel_1_hotel_1)
  end

  test "should get index" do
    get api_v1_plates_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")
    assert json_response["data"].is_a?(Array)
  end

  test "should show plate" do
    get api_v1_plate_url(@plate.barcode), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response.key?("data")
    assert_equal @plate.barcode, json_response["data"]["barcode"]
  end

  test "should create plate" do
    assert_difference("Plate.count") do
      post api_v1_plates_url, params: {
        plate: { barcode: "API_TEST_001" }
      }, as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "API_TEST_001", json_response["data"]["barcode"]
  end

  test "should update plate" do
    patch api_v1_plate_url(@plate.barcode), params: {
      plate: { barcode: "UPDATED_001" }
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "UPDATED_001", json_response["data"]["barcode"]
  end

  test "should destroy plate" do
    assert_difference("Plate.count", -1) do
      delete api_v1_plate_url(@plate.barcode), as: :json
    end

    assert_response :success
  end

  test "should move plate to location" do
    post move_to_location_api_v1_plate_url(@plate.barcode), params: {
      location_id: @location.id,
      moved_by: "api_test"
    }, as: :json

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["data"]["location"]["id"] == @location.id

    @plate.reload
    assert_equal @location, @plate.current_location
  end

  test "should get location history" do
    @plate.move_to_location!(@location, moved_by: "test")

    get location_history_api_v1_plate_url(@plate.barcode), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].is_a?(Array)
    assert json_response["data"].length > 0
  end

  test "should handle not found" do
    get api_v1_plate_url("NONEXISTENT"), as: :json
    assert_response :not_found

    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
  end

  test "should handle validation errors" do
    post api_v1_plates_url, params: {
      plate: { barcode: "" }
    }, as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert json_response.key?("error")
    assert json_response.key?("details")
  end
end
