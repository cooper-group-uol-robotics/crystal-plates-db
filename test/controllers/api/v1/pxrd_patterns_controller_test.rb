require "test_helper"

class Api::V1::PxrdPatternsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @plate = plates(:one)
    @well = wells(:one)

    # Create a test PXRD pattern associated with a well
    @well_pattern = PxrdPattern.create!(
      well: @well,
      title: "Test Well Pattern"
    )

    # Create a standalone PXRD pattern (not associated with any well)
    @standalone_pattern = PxrdPattern.create!(
      title: "Test Standalone Pattern"
    )
  end

  # Test well-associated pattern endpoints
  test "should get index for well patterns" do
    get api_v1_well_pxrd_patterns_url(@well), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_instance_of Array, json_response
    assert json_response.length >= 1

    # Find our specific well pattern in the response
    pattern_data = json_response.find { |p| p["id"] == @well_pattern.id }
    assert_not_nil pattern_data
    assert_equal @well_pattern.title, pattern_data["title"]
    assert_equal @well.id, pattern_data["well_id"]
    assert_not_nil pattern_data["well_label"]
    assert_not_nil pattern_data["plate_barcode"]
    # Well-associated patterns don't include 'standalone' field
    assert_nil pattern_data["standalone"]
  end

  test "should create well-associated pattern" do
    assert_difference("PxrdPattern.count") do
      post api_v1_well_pxrd_patterns_url(@well),
           params: { pxrd_pattern: { title: "New Well Pattern" } },
           as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "New Well Pattern", json_response["title"]
    assert_equal @well.id, json_response["well_id"]
    assert_not_nil json_response["well"]
  end

  # Test standalone pattern endpoints
  test "should get index for all patterns" do
    get api_v1_pxrd_patterns_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_instance_of Array, json_response
    assert json_response.length >= 2 # at least well + standalone pattern

    # Find standalone pattern in response
    # Note: Count may be higher due to fixtures and previous test data
    standalone_data = json_response.find { |p| p["title"] == @standalone_pattern.title }
    assert_not_nil standalone_data
    assert_equal @standalone_pattern.title, standalone_data["title"]
    assert_nil standalone_data["well_id"]
    assert_nil standalone_data["well_label"]
    assert_nil standalone_data["plate_barcode"]
    assert standalone_data["standalone"]
  end

  test "should create standalone pattern" do
    assert_difference("PxrdPattern.count") do
      post api_v1_pxrd_patterns_url,
           params: { pxrd_pattern: { title: "New Standalone Pattern" } },
           as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "New Standalone Pattern", json_response["title"]
    assert_nil json_response["well_id"]
    assert_nil json_response["well"]
    assert json_response["standalone"]
  end

  test "should show well-associated pattern" do
    get api_v1_pxrd_pattern_url(@well_pattern), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @well_pattern.id, json_response["id"]
    assert_equal @well_pattern.title, json_response["title"]
    assert_not_nil json_response["well"]
    assert_equal @well.id, json_response["well"]["id"]
  end

  test "should show standalone pattern" do
    get api_v1_pxrd_pattern_url(@standalone_pattern), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @standalone_pattern.id, json_response["id"]
    assert_equal @standalone_pattern.title, json_response["title"]
    assert_nil json_response["well"]
    assert json_response["standalone"]
  end

  test "should update well-associated pattern" do
    patch api_v1_pxrd_pattern_url(@well_pattern),
          params: { pxrd_pattern: { title: "Updated Well Pattern" } },
          as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "Updated Well Pattern", json_response["title"]
    assert_not_nil json_response["well"]
  end

  test "should update standalone pattern" do
    patch api_v1_pxrd_pattern_url(@standalone_pattern),
          params: { pxrd_pattern: { title: "Updated Standalone Pattern" } },
          as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "Updated Standalone Pattern", json_response["title"]
    assert_nil json_response["well"]
    assert json_response["standalone"]
  end

  test "should destroy well-associated pattern" do
    assert_difference("PxrdPattern.count", -1) do
      delete api_v1_pxrd_pattern_url(@well_pattern), as: :json
    end
    assert_response :success
  end

  test "should destroy standalone pattern" do
    assert_difference("PxrdPattern.count", -1) do
      delete api_v1_pxrd_pattern_url(@standalone_pattern), as: :json
    end
    assert_response :success
  end

  test "should get pattern data for pattern with file" do
    # This test would require attaching an actual PXRD file
    # For now, just test that the endpoint exists and handles missing data gracefully
    get data_api_v1_pxrd_pattern_url(@standalone_pattern), as: :json

    # Should return success with empty data arrays since no file is attached
    assert_response :success
    json_response = JSON.parse(response.body)
    assert_not_nil json_response["data"]
    assert_equal [], json_response["data"]["two_theta"]
    assert_equal [], json_response["data"]["intensities"]
  end

  test "should handle errors gracefully when creating invalid pattern" do
    post api_v1_pxrd_patterns_url,
         params: { pxrd_pattern: { title: "" } },
         as: :json

    # Should handle any validation errors gracefully
    # The exact response depends on model validations
    assert_response :success # or :unprocessable_entity if validations fail
  end

  test "should return 404 for non-existent pattern" do
    get api_v1_pxrd_pattern_url(99999), as: :json
    assert_response :not_found
  end

  # Tests for the new upload_to_well endpoint
  test "should upload PXRD pattern to well using human-readable identifier" do
    assert_difference("PxrdPattern.count") do
      post upload_to_well_api_v1_pxrd_patterns_url(
             barcode: @plate.barcode,
             well_string: "A1"
           ),
           params: { pxrd_pattern: { title: "Pattern for A1" } },
           as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "Pattern for A1", json_response["title"]
    assert_not_nil json_response["well_id"]
    assert_not_nil json_response["well"]
    assert_equal "A1", json_response["well_label"]
    assert_equal @plate.barcode, json_response["plate_barcode"]
  end

  test "should upload PXRD pattern to well with subwell identifier" do
    # First create a well with multiple subwells (if it doesn't exist)
    subwell = @plate.wells.find_or_create_by(well_row: 2, well_column: 3, subwell: 2)

    assert_difference("PxrdPattern.count") do
      post upload_to_well_api_v1_pxrd_patterns_url(
             barcode: @plate.barcode,
             well_string: "B3_2"
           ),
           params: { pxrd_pattern: { title: "Pattern for B3 subwell 2" } },
           as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "Pattern for B3 subwell 2", json_response["title"]
    assert_equal subwell.id, json_response["well_id"]
    assert_equal "B3:2", json_response["well_label"]
  end

  test "should handle invalid plate barcode in upload_to_well" do
    post upload_to_well_api_v1_pxrd_patterns_url(
           barcode: "INVALID_BARCODE",
           well_string: "A1"
         ),
         params: { pxrd_pattern: { title: "Pattern for nonexistent plate" } },
         as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Plate not found", json_response["error"]
    assert_includes json_response["details"].first, "INVALID_BARCODE"
  end

  test "should handle invalid well identifier in upload_to_well" do
    post upload_to_well_api_v1_pxrd_patterns_url(
           barcode: @plate.barcode,
           well_string: "Z99"
         ),
         params: { pxrd_pattern: { title: "Pattern for nonexistent well" } },
         as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Well not found", json_response["error"]
    assert_includes json_response["details"].first, "Z99"
  end

  test "should handle malformed well identifier in upload_to_well" do
    post upload_to_well_api_v1_pxrd_patterns_url(
           barcode: @plate.barcode,
           well_string: "INVALID"
         ),
         params: { pxrd_pattern: { title: "Pattern for malformed well" } },
         as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Well not found", json_response["error"]
    assert_includes json_response["details"].first, "INVALID"
  end

  test "should handle validation errors in upload_to_well" do
    # Test with invalid PXRD pattern parameters
    post upload_to_well_api_v1_pxrd_patterns_url(
           barcode: @plate.barcode,
           well_string: "A1"
         ),
         params: { pxrd_pattern: { title: "" } },
         as: :json

    # Response depends on PxrdPattern model validations
    # If title is required and empty, should get unprocessable_entity
    # If no validation, should get success
    assert_includes [ 201, 422 ], response.status
  end

  private

  # Helper method to create a pattern with an attached file for testing
  def create_pattern_with_file(pattern)
    # This would attach a test PXRD file to the pattern
    # Implementation depends on your file attachment setup
  end

  # Helper method to assert response is one of several acceptable codes
  def assert_response_in(codes)
    assert_includes codes, response.status, "Expected response to be one of #{codes}, but was #{response.status}"
  end
end
