require "test_helper"

class PlatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @plate = plates(:one)
    sign_in users(:writable)
  end

  test "should get index" do
    get plates_url
    assert_response :success
  end

  test "should sort plates by barcode descending by default" do
    # Use barcodes that sort predictably
    Plate.create!(barcode: "AAA-TEST-001")
    Plate.create!(barcode: "ZZZ-TEST-003")
    Plate.create!(barcode: "MMM-TEST-002")

    get plates_url
    assert_response :success

    # Default sort is descending, so check ZZZ appears before MMM appears before AAA
    response_body = response.body
    aaa_pos = response_body.index("AAA-TEST-001")
    mmm_pos = response_body.index("MMM-TEST-002")
    zzz_pos = response_body.index("ZZZ-TEST-003")

    assert zzz_pos < mmm_pos, "ZZZ-TEST-003 should appear before MMM-TEST-002 (desc order)"
    assert mmm_pos < aaa_pos, "MMM-TEST-002 should appear before AAA-TEST-001 (desc order)"
  end

  test "should sort plates by barcode descending when requested" do
    # Use unique test barcodes
    Plate.create!(barcode: "AAA-DESC-TEST")
    Plate.create!(barcode: "ZZZ-DESC-TEST")

    get plates_url, params: { sort: "barcode", direction: "desc" }
    assert_response :success

    # Check that barcodes appear in reverse sorted order
    response_body = response.body
    aaa_pos = response_body.index("AAA-DESC-TEST")
    zzz_pos = response_body.index("ZZZ-DESC-TEST")

    assert zzz_pos < aaa_pos, "ZZZ-DESC-TEST should appear before AAA-DESC-TEST in desc order"
  end

  test "should sort plates by created_at when requested" do
    # Create plates at different times with unique barcodes
    Plate.create!(barcode: "NEWER-TIME-TEST", created_at: 1.day.ago)
    Plate.create!(barcode: "OLDER-TIME-TEST", created_at: 2.days.ago)

    get plates_url, params: { sort: "created_at", direction: "asc" }
    assert_response :success

    # Check that older plate appears first
    response_body = response.body
    older_pos = response_body.index("OLDER-TIME-TEST")
    newer_pos = response_body.index("NEWER-TIME-TEST")

    assert older_pos < newer_pos, "Older plate should appear before newer plate"
  end

  test "should handle invalid sort parameters gracefully" do
    get plates_url, params: { sort: "invalid_column", direction: "invalid_direction" }
    assert_response :success
    # Should fall back to default sorting without errors
  end

  test "plates index should not have N+1 queries" do
    # Create multiple plates with locations
    location1 = Location.create!(name: "test_loc_1")
    location2 = Location.create!(name: "test_loc_2")

    plate1 = Plate.create!(barcode: "TEST1")
    plate2 = Plate.create!(barcode: "TEST2")
    Plate.create!(barcode: "TEST3")  # plate without location

    plate1.move_to_location!(location1)
    plate2.move_to_location!(location2)

    # Count queries during the request
    queries_count = 0
    ActiveSupport::Notifications.subscribe("sql.active_record") do |name, started, finished, unique_id, data|
      queries_count += 1 unless data[:sql].include?("SCHEMA")
    end

    get plates_url
    assert_response :success

    # Should be efficient - exact count may vary but should be reasonable
    assert queries_count < 20, "Too many queries (#{queries_count}), possible N+1 issue"
  end

  test "should validate sorting parameters and efficiency" do
    # Create multiple plates to test sorting
    Plate.create!(barcode: "BETA", created_at: 2.days.ago)
    Plate.create!(barcode: "ALPHA", created_at: 1.day.ago)

    # Test sorting by barcode ascending
    get plates_url, params: { sort: "barcode", direction: "asc" }
    assert_response :success

    # Test sorting by barcode descending
    get plates_url, params: { sort: "barcode", direction: "desc" }
    assert_response :success

    # Test sorting by created_at
    get plates_url, params: { sort: "created_at", direction: "desc" }
    assert_response :success

    # Test invalid sort column falls back gracefully
    get plates_url, params: { sort: "invalid_column" }
    assert_response :success

    # Test invalid direction falls back gracefully
    get plates_url, params: { sort: "barcode", direction: "invalid" }
    assert_response :success
  end

  test "plates index includes current location information efficiently" do
    # Create plate with location
    location = Location.create!(name: "test_location")
    plate = Plate.create!(barcode: "LOCATION_TEST")
    plate.move_to_location!(location)

    get plates_url
    assert_response :success

    # Response should include location information
    assert_match location.display_name, response.body
    assert_match plate.barcode, response.body
  end

  test "should get new" do
    get new_plate_url
    assert_response :success
  end

  test "should create plate" do
    assert_difference("Plate.count") do
      post plates_url, params: { plate: { barcode: "UNIQUE_TEST_BARCODE" } }
    end

    assert_redirected_to plate_url(Plate.last)
  end

  test "should create plate without barcode and generate one automatically" do
    assert_difference("Plate.count") do
      post plates_url, params: { plate: { barcode: "" } }
    end

    created_plate = Plate.last
    assert_not_nil created_plate.barcode
    assert_not_equal "", created_plate.barcode

    # Should follow the expected format
    assert_match(/\A6\d{7}\z/, created_plate.barcode)

    assert_redirected_to plate_url(created_plate)
  end

  test "should show plate" do
    get plate_url(@plate)
    assert_response :success
  end

  test "should get edit" do
    get edit_plate_url(@plate)
    assert_response :success
  end

  test "should update plate" do
    patch plate_url(@plate), params: { plate: { barcode: @plate.barcode } }
    assert_redirected_to plate_url(@plate)
  end

  test "should unassign plate location on update" do
    # Create a location and assign the plate to it
    location = Location.create!(name: "Test Location")
    @plate.move_to_location!(location)

    # Verify the plate is assigned
    assert_not_nil @plate.current_location
    assert_equal location.id, @plate.current_location.id

    # Update the plate to be unassigned
    patch plate_url(@plate), params: {
      plate: { barcode: @plate.barcode },
      location_type: "unassigned"
    }

    # Verify the update was successful
    assert_redirected_to plate_url(@plate)

    # Reload the plate and verify it's now unassigned
    @plate.reload
    assert_nil @plate.current_location, "Plate should be unassigned after update"
    assert @plate.unassigned?, "Plate should be marked as unassigned"
  end

  test "should assign plate to location on update" do
    # Create a location with unique positions
    location = Location.create!(carousel_position: 99, hotel_position: 99)

    # Ensure the plate starts unassigned
    @plate.unassign_location! if @plate.current_location

    # Update the plate to be assigned to the location
    patch plate_url(@plate), params: {
      plate: { barcode: @plate.barcode },
      location_type: "carousel",
      carousel_position: "99",
      hotel_position: "99"
    }

    # Verify the update was successful
    assert_redirected_to plate_url(@plate)

    # Reload the plate and verify it's now assigned
    @plate.reload
    assert_not_nil @plate.current_location, "Plate should be assigned after update"
    assert_equal location.id, @plate.current_location.id
    assert @plate.assigned?, "Plate should be marked as assigned"
  end

  test "should destroy plate" do
    assert_difference("Plate.count", -1) do
      delete plate_url(@plate)
    end

    assert_redirected_to plates_url
  end
end
