require "test_helper"

class PlateLocationTest < ActiveSupport::TestCase
  setup do
    @plate = plates(:one)
    @location = locations(:carousel_1_hotel_1)
    @imager_location = locations(:imager)
  end

  test "should create valid plate location" do
    plate_location = PlateLocation.new(
      plate: @plate,
      location: @location,
      moved_at: Time.current
    )

    assert plate_location.valid?
    assert plate_location.save
  end

  test "should require plate" do
    plate_location = PlateLocation.new(
      location: @location,
      moved_at: Time.current
    )

    assert_not plate_location.valid?
    assert_includes plate_location.errors[:plate], "must exist"
  end

  test "should require location" do
    plate_location = PlateLocation.new(
      plate: @plate,
      moved_at: Time.current
    )

    assert_not plate_location.valid?
    assert_includes plate_location.errors[:location], "must exist"
  end

  test "should require moved_at" do
    plate_location = PlateLocation.new(
      plate: @plate,
      location: @location
    )

    assert_not plate_location.valid?
    assert_includes plate_location.errors[:moved_at], "can't be blank"
  end

  test "should belong to plate" do
    plate_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: Time.current
    )

    assert_equal @plate, plate_location.plate
  end

  test "should belong to location" do
    plate_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: Time.current
    )

    assert_equal @location, plate_location.location
  end

  test "ordered_by_date scope should order by moved_at ascending" do
    # Create plate locations with different timestamps
    time1 = 2.hours.ago
    time2 = 1.hour.ago
    time3 = Time.current

    pl1 = PlateLocation.create!(plate: @plate, location: @location, moved_at: time2)
    pl2 = PlateLocation.create!(plate: @plate, location: @imager_location, moved_at: time1)
    pl3 = PlateLocation.create!(plate: @plate, location: @location, moved_at: time3)

    ordered = PlateLocation.ordered_by_date

    # Should be in ascending order (oldest first)
    assert_equal pl2.id, ordered.first.id  # time1 (oldest)
    assert_equal pl3.id, ordered.last.id   # time3 (newest)
  end

  test "recent_first scope should order by moved_at descending" do
    # Create plate locations with different timestamps
    time1 = 2.hours.ago
    time2 = 1.hour.ago
    time3 = Time.current

    pl1 = PlateLocation.create!(plate: @plate, location: @location, moved_at: time2)
    pl2 = PlateLocation.create!(plate: @plate, location: @imager_location, moved_at: time1)
    pl3 = PlateLocation.create!(plate: @plate, location: @location, moved_at: time3)

    recent = PlateLocation.recent_first

    # Should be in descending order (newest first)
    assert_equal pl3.id, recent.first.id  # time3 (newest)
    assert_equal pl2.id, recent.last.id   # time1 (oldest)
  end

  test "should handle multiple plate locations for same plate" do
    # Move plate through multiple locations
    pl1 = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: 1.hour.ago
    )

    pl2 = PlateLocation.create!(
      plate: @plate,
      location: @imager_location,
      moved_at: Time.current
    )

    # Both should exist
    assert pl1.persisted?
    assert pl2.persisted?

    # Plate should have multiple locations in history
    assert_equal 2, @plate.plate_locations.count
    assert_includes @plate.plate_locations, pl1
    assert_includes @plate.plate_locations, pl2
  end

  test "should handle multiple plates at different locations" do
    plate2 = Plate.create!(barcode: "TEST_PLATE_2")

    pl1 = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: Time.current
    )

    pl2 = PlateLocation.create!(
      plate: plate2,
      location: @imager_location,
      moved_at: Time.current
    )

    # Both should exist
    assert pl1.persisted?
    assert pl2.persisted?

    # Each location should have its respective plate
    assert_includes @location.plate_locations, pl1
    assert_includes @imager_location.plate_locations, pl2
  end

  test "moved_at should be stored as datetime" do
    now = Time.current
    plate_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: now
    )

    assert_kind_of Time, plate_location.moved_at
    assert_in_delta now.to_f, plate_location.moved_at.to_f, 1.0
  end

  test "should destroy plate location when location is destroyed" do
    plate_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: Time.current
    )

    plate_location_id = plate_location.id
    @location.destroy

    assert_raises(ActiveRecord::RecordNotFound) do
      PlateLocation.find(plate_location_id)
    end
  end

  test "should track movement history chronologically" do
    # Create a movement history
    pl1 = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: 3.hours.ago
    )

    pl2 = PlateLocation.create!(
      plate: @plate,
      location: @imager_location,
      moved_at: 2.hours.ago
    )

    pl3 = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: 1.hour.ago
    )

    # Get chronological history
    history = @plate.plate_locations.ordered_by_date

    assert_equal 3, history.count
    assert_equal [ @location.id, @imager_location.id, @location.id ],
                 history.map(&:location_id)

    # Get recent history
    recent = @plate.plate_locations.recent_first

    assert_equal [ @location.id, @imager_location.id, @location.id ],
                 recent.map(&:location_id)
  end
end
