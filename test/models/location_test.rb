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
    @plate1.move_to_location!(@carousel_location)

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

  # Test optimization methods
  test "occupied? method works correctly" do
    # Test empty location
    assert_not @carousel_location.occupied?, "Empty location should not be occupied"

    # Move plate to location
    @plate1.move_to_location!(@carousel_location)
    @carousel_location.reload

    assert @carousel_location.occupied?, "Location with plate should be occupied"
  end

  test "occupied? method works with preloaded virtual attribute" do
    # Move plate to location
    @plate1.move_to_location!(@carousel_location)

    # Test with virtual attribute from scope
    location_with_status = Location.with_occupation_status.find(@carousel_location.id)
    assert location_with_status.occupied?, "Location should be occupied when loaded with scope"

    # Test empty location
    empty_location = Location.create!(name: "empty_test")
    location_empty_with_status = Location.with_occupation_status.find(empty_location.id)
    assert_not location_empty_with_status.occupied?, "Empty location should not be occupied when loaded with scope"
  end

  test "current_plate_id method works correctly" do
    # Test empty location
    empty_location = Location.create!(name: "empty_test")
    assert_nil empty_location.current_plate_id, "Empty location should have no current plate ID"

    # Move plate to location
    @plate1.move_to_location!(@carousel_location)
    @carousel_location.reload

    assert_equal @plate1.id, @carousel_location.current_plate_id, "Should return correct plate ID"
  end

  test "current_plate_barcode method works correctly" do
    # Test empty location
    empty_location = Location.create!(name: "empty_test")
    assert_nil empty_location.current_plate_barcode, "Empty location should have no current plate barcode"

    # Move plate to location
    @plate1.move_to_location!(@carousel_location)
    @carousel_location.reload

    assert_equal @plate1.barcode, @carousel_location.current_plate_barcode, "Should return correct plate barcode"
  end

  test "has_current_plate? method works correctly" do
    # Test empty location
    empty_location = Location.create!(name: "empty_test")
    assert_not empty_location.has_current_plate?, "Empty location should not have current plate"

    # Move plate to location
    @plate1.move_to_location!(@carousel_location)
    @carousel_location.reload

    assert @carousel_location.has_current_plate?, "Location with plate should have current plate"
  end

  test "with_occupation_status scope works correctly" do
    # Move plate to location
    @plate1.move_to_location!(@carousel_location)

    location = Location.with_occupation_status.find(@carousel_location.id)

    # Should be occupied
    assert location.occupied?, "Location with plate should be occupied"
  end

  test "with_current_plate_data scope preloads associations efficiently" do
    # Move plate to location
    @plate1.move_to_location!(@carousel_location)

    # This should not trigger additional queries when accessing current_plates
    location = Location.with_current_plate_data.find(@carousel_location.id)

    # Should be able to access current plates without additional queries
    current_plates = location.current_plates.to_a
    assert_equal 1, current_plates.size
    assert_equal @plate1.id, current_plates.first.id
  end

  test "scopes work efficiently with multiple locations" do
    # Create multiple locations and plates
    location1 = Location.create!(name: "test_1")
    location2 = Location.create!(name: "test_2")
    location3 = Location.create!(name: "test_3") # will remain empty

    plate1 = Plate.create!(barcode: "SCOPE_TEST_1")
    plate2 = Plate.create!(barcode: "SCOPE_TEST_2")

    # Move plates to locations
    plate1.move_to_location!(location1)
    plate2.move_to_location!(location2)

    # Test with_occupation_status scope
    locations_with_status = Location.with_occupation_status
                                   .where(id: [ location1.id, location2.id, location3.id ])
                                   .index_by(&:id)

    assert locations_with_status[location1.id].occupied?
    assert locations_with_status[location2.id].occupied?
    assert_not locations_with_status[location3.id].occupied?

    # Test with_current_plate_data scope
    locations_with_data = Location.with_current_plate_data
                                 .where(id: [ location1.id, location2.id, location3.id ])
                                 .index_by(&:id)

    assert_equal plate1.id, locations_with_data[location1.id].current_plate_id
    assert_equal plate2.id, locations_with_data[location2.id].current_plate_id
    assert_nil locations_with_data[location3.id].current_plate_id
  end

  test "current_plate_locations association works correctly" do
    location = Location.create!(name: "current_plate_test")
    plate = Plate.create!(barcode: "CURRENT_PLATE_TEST")

    # Initially no current plate locations
    assert_empty location.current_plate_locations

    # Move plate to location
    plate.move_to_location!(location)
    location.reload

    # Should have one current plate location
    assert_equal 1, location.current_plate_locations.count
    assert_equal plate.id, location.current_plate_locations.first.plate_id

    # Move plate away
    other_location = Location.create!(name: "other")
    plate.move_to_location!(other_location)
    location.reload

    # Should have no current plate locations
    assert_empty location.current_plate_locations
  end

  test "current_plates association works correctly" do
    location = Location.create!(name: "current_plates_test")
    plate = Plate.create!(barcode: "CURRENT_PLATES_TEST")

    # Initially no current plates
    assert_empty location.current_plates

    # Move plate to location
    plate.move_to_location!(location)
    location.reload

    # Should have one current plate
    assert_equal 1, location.current_plates.count
    assert_equal plate.id, location.current_plates.first.id

    # Move plate away
    other_location = Location.create!(name: "other")
    plate.move_to_location!(other_location)
    location.reload

    # Should have no current plates
    assert_empty location.current_plates
  end

  # Tests for the specific occupancy scenario: plate created -> moved -> new plate created
  test "location should allow new plate after previous plate moves away" do
    # Create two locations
    location_a = Location.create!(name: "location_a")
    location_b = Location.create!(name: "location_b")

    # Step 1: Create first plate in location A
    plate1 = Plate.create!(barcode: "PLATE_001")
    plate1.move_to_location!(location_a)

    # Verify location A is occupied by plate1
    location_a.reload
    assert location_a.occupied?, "Location A should be occupied by plate1"
    assert_equal plate1.id, location_a.current_plate_id
    assert_equal 1, location_a.current_plates.count
    assert_includes location_a.current_plates, plate1

    # Verify location B is empty
    location_b.reload
    assert_not location_b.occupied?, "Location B should be empty"
    assert_empty location_b.current_plates

    # Step 2: Move plate1 from location A to location B
    plate1.move_to_location!(location_b)

    # Verify location A is now empty
    location_a.reload
    assert_not location_a.occupied?, "Location A should be empty after plate1 moved away"
    assert_empty location_a.current_plates
    assert_nil location_a.current_plate_id

    # Verify location B now has plate1
    location_b.reload
    assert location_b.occupied?, "Location B should be occupied by plate1"
    assert_equal plate1.id, location_b.current_plate_id
    assert_equal 1, location_b.current_plates.count
    assert_includes location_b.current_plates, plate1

    # Step 3: Create second plate in location A (should succeed)
    plate2 = Plate.create!(barcode: "PLATE_002")

    # This should NOT raise an error
    assert_nothing_raised do
      plate2.move_to_location!(location_a)
    end

    # Verify final state
    location_a.reload
    location_b.reload

    # Location A should have plate2
    assert location_a.occupied?, "Location A should be occupied by plate2"
    assert_equal plate2.id, location_a.current_plate_id
    assert_equal 1, location_a.current_plates.count
    assert_includes location_a.current_plates, plate2
    assert_not_includes location_a.current_plates, plate1

    # Location B should still have plate1
    assert location_b.occupied?, "Location B should still be occupied by plate1"
    assert_equal plate1.id, location_b.current_plate_id
    assert_equal 1, location_b.current_plates.count
    assert_includes location_b.current_plates, plate1
    assert_not_includes location_b.current_plates, plate2
  end

  test "carousel location should allow new plate after previous plate moves away" do
    # Create two carousel locations
    location_a = Location.create!(carousel_position: 1, hotel_position: 1)
    location_b = Location.create!(carousel_position: 2, hotel_position: 1)

    # Step 1: Create first plate in carousel location A
    plate1 = Plate.create!(barcode: "CAROUSEL_001")
    plate1.move_to_location!(location_a)

    # Verify location A is occupied
    location_a.reload
    assert location_a.occupied?
    assert_equal plate1.id, location_a.current_plate_id

    # Step 2: Move plate to location B
    plate1.move_to_location!(location_b)

    # Verify location A is empty
    location_a.reload
    assert_not location_a.occupied?
    assert_empty location_a.current_plates

    # Step 3: Create second plate in location A
    plate2 = Plate.create!(barcode: "CAROUSEL_002")

    # This should succeed
    assert_nothing_raised do
      plate2.move_to_location!(location_a)
    end

    # Verify final state
    location_a.reload
    assert location_a.occupied?
    assert_equal plate2.id, location_a.current_plate_id
  end

  test "location should prevent duplicate occupancy" do
    location = Location.create!(name: "single_occupancy_test")

    # Create and place first plate
    plate1 = Plate.create!(barcode: "FIRST_PLATE")
    plate1.move_to_location!(location)

    # Try to place second plate in same location - should fail
    plate2 = Plate.create!(barcode: "SECOND_PLATE")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      plate2.move_to_location!(location)
    end

    assert_includes error.message, "already occupied by plate FIRST_PLATE"

    # Verify location still only has first plate
    location.reload
    assert_equal 1, location.current_plates.count
    assert_equal plate1.id, location.current_plate_id
  end

  test "complex movement scenario with multiple plates and locations" do
    # Create multiple locations
    storage = Location.create!(name: "storage")
    imager = Location.create!(name: "imager")
    carousel_1_1 = Location.create!(carousel_position: 1, hotel_position: 1)
    carousel_1_2 = Location.create!(carousel_position: 1, hotel_position: 2)

    # Create multiple plates
    plate_a = Plate.create!(barcode: "COMPLEX_A")
    plate_b = Plate.create!(barcode: "COMPLEX_B")
    plate_c = Plate.create!(barcode: "COMPLEX_C")

    # Initial movements
    plate_a.move_to_location!(storage)
    plate_b.move_to_location!(imager)
    plate_c.move_to_location!(carousel_1_1)

    # Verify initial state
    [ storage, imager, carousel_1_1, carousel_1_2 ].each(&:reload)
    assert storage.occupied?
    assert imager.occupied?
    assert carousel_1_1.occupied?
    assert_not carousel_1_2.occupied?

    # Move plates around
    plate_a.move_to_location!(carousel_1_2)  # storage -> carousel_1_2
    plate_c.move_to_location!(storage)       # carousel_1_1 -> storage

    # Verify intermediate state
    [ storage, imager, carousel_1_1, carousel_1_2 ].each(&:reload)
    assert storage.occupied?     # now has plate_c
    assert imager.occupied?      # still has plate_b
    assert_not carousel_1_1.occupied?  # now empty
    assert carousel_1_2.occupied?      # now has plate_a

    assert_equal plate_c.id, storage.current_plate_id
    assert_equal plate_b.id, imager.current_plate_id
    assert_equal plate_a.id, carousel_1_2.current_plate_id

    # Try to place plate_b in now-empty carousel_1_1 - should succeed
    plate_b.move_to_location!(carousel_1_1)

    # Final verification
    [ storage, imager, carousel_1_1, carousel_1_2 ].each(&:reload)
    assert storage.occupied?        # plate_c
    assert_not imager.occupied?     # now empty
    assert carousel_1_1.occupied?   # now has plate_b
    assert carousel_1_2.occupied?   # still has plate_a

    assert_equal plate_c.id, storage.current_plate_id
    assert_equal plate_b.id, carousel_1_1.current_plate_id
    assert_equal plate_a.id, carousel_1_2.current_plate_id
    assert_nil imager.current_plate_id
  end

  test "historical movements should not affect current occupancy" do
    location_a = Location.create!(name: "historical_test_a")
    location_b = Location.create!(name: "historical_test_b")

    plate = Plate.create!(barcode: "HISTORICAL_PLATE")

    # Create a complex movement history
    plate.move_to_location!(location_a)  # Move to A
    sleep(0.01)  # Ensure different timestamps
    plate.move_to_location!(location_b)  # Move to B
    sleep(0.01)
    plate.move_to_location!(location_a)  # Move back to A
    sleep(0.01)
    plate.move_to_location!(location_b)  # Move back to B

    # Verify that only the final location shows as occupied
    location_a.reload
    location_b.reload

    assert_not location_a.occupied?, "Location A should not be occupied (plate moved away)"
    assert location_b.occupied?, "Location B should be occupied (plate's current location)"
    assert_empty location_a.current_plates
    assert_equal 1, location_b.current_plates.count
    assert_equal plate.id, location_b.current_plate_id

    # Verify that location A can accept a new plate
    new_plate = Plate.create!(barcode: "NEW_AFTER_HISTORY")

    # Should be able to place new plate in location A
    assert_nothing_raised do
      new_plate.move_to_location!(location_a)
    end

    # Final state verification
    location_a.reload
    location_b.reload

    assert location_a.occupied?, "Location A should now be occupied by new plate"
    assert location_b.occupied?, "Location B should still be occupied by original plate"
    assert_equal new_plate.id, location_a.current_plate_id
    assert_equal plate.id, location_b.current_plate_id
  end
end
