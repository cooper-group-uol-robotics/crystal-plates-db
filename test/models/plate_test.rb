require "test_helper"

class PlateTest < ActiveSupport::TestCase
  setup do
    @plate1 = plates(:one)
    @plate2 = plates(:two)
    @carousel_location = locations(:carousel_1_hotel_1)
    @imager_location = locations(:imager)
  end

  test "should create plate with valid barcode" do
    plate = Plate.new(barcode: "12345678")
    assert plate.valid?
    assert plate.save
  end

  test "should generate barcode automatically when none provided" do
    plate = Plate.new
    assert plate.valid?
    assert plate.save

    # Should have generated a barcode
    assert_not_nil plate.barcode
    assert_not_equal "", plate.barcode

    # Should follow the expected format: PLT + timestamp + random suffix
    assert_match(/\A6\d{7}\z/, plate.barcode)
  end

  test "should not override existing barcode when provided" do
    custom_barcode = "CUSTOM123"
    plate = Plate.new(barcode: custom_barcode)
    assert plate.valid?
    assert plate.save

    # Should keep the custom barcode
    assert_equal custom_barcode, plate.barcode
  end

  test "should generate unique barcodes for multiple plates" do
    plate1 = Plate.create!
    plate2 = Plate.create!

    # Both should have generated barcodes
    assert_not_nil plate1.barcode
    assert_not_nil plate2.barcode

    # Barcodes should be different
    assert_not_equal plate1.barcode, plate2.barcode
  end

  test "should handle barcode generation with existing conflicts" do
    # Create a plate with a specific barcode
    existing_plate = Plate.create!(barcode: "EXISTING123")

    # Create new plate - it should generate a unique barcode
    new_plate = Plate.create!

    assert_not_nil new_plate.barcode
    assert_not_equal existing_plate.barcode, new_plate.barcode
    assert new_plate.valid?

    # Test that the generated barcode follows the expected pattern
    assert_match(/\A6\d{7}\z/, new_plate.barcode)
  end

  test "should not create plate with duplicate barcode" do
    existing_barcode = @plate1.barcode
    plate = Plate.new(barcode: existing_barcode)
    assert_not plate.valid?
    assert_includes plate.errors[:barcode], "has already been taken"
  end

  test "should move plate to location successfully" do
    assert_nil @plate1.current_location

    @plate1.move_to_location!(@carousel_location)

    assert_equal @carousel_location, @plate1.current_location
    assert_equal 1, @plate1.plate_locations.count
  end

  test "should prevent moving two plates to same location" do
    # Move first plate to location
    @plate1.move_to_location!(@carousel_location)
    assert_equal @carousel_location, @plate1.current_location

    # Try to move second plate to same location - should fail
    assert_raises(ActiveRecord::RecordInvalid) do
      @plate2.move_to_location!(@carousel_location)
    end

    # Verify second plate was not moved
    assert_nil @plate2.current_location
    assert_equal @carousel_location, @plate1.current_location
  end

  test "should allow moving plate to different location" do
    # Move plate to first location
    @plate1.move_to_location!(@carousel_location)
    assert_equal @carousel_location, @plate1.current_location

    # Move same plate to different location - should succeed
    @plate1.move_to_location!(@imager_location)
    assert_equal @imager_location, @plate1.current_location
    assert_equal 2, @plate1.plate_locations.count
  end

  test "should allow different plates in different locations" do
    # Move plates to different locations
    @plate1.move_to_location!(@carousel_location)
    @plate2.move_to_location!(@imager_location)

    assert_equal @carousel_location, @plate1.current_location
    assert_equal @imager_location, @plate2.current_location
  end

  test "should track location history" do
    # Move plate through multiple locations
    @plate1.move_to_location!(@carousel_location)
    @plate1.move_to_location!(@imager_location)

    history = @plate1.location_history
    assert_equal 2, history.count

    # Most recent should be imager
    assert_equal @imager_location, history.first.location
    # Previous should be carousel
    assert_equal @carousel_location, history.second.location
  end

  test "should create wells after plate creation" do
    plate = Plate.create!(barcode: "WELLS_TEST")

    # Should create 8x12 = 96 wells
    assert_equal 96, plate.wells.count

    # Check row and column ranges
    assert_equal 8, plate.wells.maximum(:well_row)
    assert_equal 12, plate.wells.maximum(:well_column)
    assert_equal 1, plate.wells.minimum(:well_row)
    assert_equal 1, plate.wells.minimum(:well_column)
  end

  test "should calculate rows and columns correctly" do
    # Create a fresh plate to ensure it has wells
    plate = Plate.create!(barcode: "ROWS_COLS_TEST")
    assert_equal 8, plate.rows
    assert_equal 12, plate.columns
  end

  test "current_location method works efficiently" do
    # Test plate without location
    assert_nil @plate1.current_location

    # Move plate to location
    @plate1.move_to_location!(@carousel_location)

    # Should return the current location
    assert_equal @carousel_location, @plate1.current_location

    # Move to different location
    @plate1.move_to_location!(@imager_location)

    # Should return new location
    assert_equal @imager_location, @plate1.current_location
  end

  test "unassigned scope returns plates without location" do
    # Create an unassigned plate
    unassigned_plate = Plate.create!(barcode: "UNASSIGNED")
    unassigned_plate.unassign_location!

    # Create an assigned plate
    assigned_plate = Plate.create!(barcode: "ASSIGNED")
    assigned_plate.move_to_location!(@carousel_location)

    unassigned_plates = Plate.unassigned
    assigned_plates = Plate.assigned

    assert_includes unassigned_plates, unassigned_plate
    assert_not_includes unassigned_plates, assigned_plate

    assert_includes assigned_plates, assigned_plate
    assert_not_includes assigned_plates, unassigned_plate
  end

  test "multiple plates can be tracked efficiently" do
    plate2 = Plate.create!(barcode: "MULTI_TEST_2")
    plate3 = Plate.create!(barcode: "MULTI_TEST_3")
    location2 = Location.create!(name: "multi_test_location")

    # Move plates to different locations
    @plate1.move_to_location!(@carousel_location)
    plate2.move_to_location!(@imager_location)
    # plate3 remains without location

    # Test current locations
    assert_equal @carousel_location, @plate1.current_location
    assert_equal @imager_location, plate2.current_location
    assert_nil plate3.current_location

    # Test location occupancy
    assert @carousel_location.occupied?
    assert @imager_location.occupied?
    assert_not location2.occupied?
  end

  test "should handle plate without location gracefully" do
    assert_nil @plate1.current_location
    assert_empty @plate1.location_history
  end

  test "should validate location occupancy with error message" do
    # Move first plate to location
    @plate1.move_to_location!(@carousel_location)

    # Try to move second plate to same location
    begin
      @plate2.move_to_location!(@carousel_location)
      flunk "Expected ActiveRecord::RecordInvalid to be raised"
    rescue ActiveRecord::RecordInvalid => e
      error_message = e.record.errors.full_messages.first
      assert_includes error_message, "already occupied by plate"
      assert_includes error_message, @plate1.barcode
    end
  end
end
