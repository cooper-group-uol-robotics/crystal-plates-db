require "test_helper"

class PlateLocationTest < ActiveSupport::TestCase
  setup do
    @plate = plates(:one)
    @location = locations(:carousel_1_hotel_1)
  end

  test "should create valid plate_location" do
    plate_location = PlateLocation.new(
      plate: @plate,
      location: @location,
      moved_at: Time.current,
      moved_by: "test_user"
    )
    assert plate_location.valid?
    assert plate_location.save
  end

  test "should not create plate_location without plate" do
    plate_location = PlateLocation.new(
      location: @location,
      moved_at: Time.current,
      moved_by: "test_user"
    )
    assert_not plate_location.valid?
    assert_includes plate_location.errors[:plate], "must exist"
  end

  test "should not create plate_location without location" do
    plate_location = PlateLocation.new(
      plate: @plate,
      moved_at: Time.current,
      moved_by: "test_user"
    )
    assert_not plate_location.valid?
    assert_includes plate_location.errors[:location], "must exist"
  end

  test "should not create plate_location without moved_at" do
    plate_location = PlateLocation.new(
      plate: @plate,
      location: @location,
      moved_by: "test_user"
    )
    assert_not plate_location.valid?
    assert_includes plate_location.errors[:moved_at], "can't be blank"
  end

  test "should not create plate_location without moved_by" do
    plate_location = PlateLocation.new(
      plate: @plate,
      location: @location,
      moved_at: Time.current
    )
    assert_not plate_location.valid?
    assert_includes plate_location.errors[:moved_by], "can't be blank"
  end

  test "should belong to plate" do
    plate_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: Time.current,
      moved_by: "test_user"
    )
    assert_equal @plate, plate_location.plate
  end

  test "should belong to location" do
    plate_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: Time.current,
      moved_by: "test_user"
    )
    assert_equal @location, plate_location.location
  end

  test "ordered_by_date scope should order by moved_at ascending" do
    later_time = 1.hour.from_now
    earlier_time = 1.hour.ago

    later_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: later_time,
      moved_by: "test_user"
    )

    earlier_location = PlateLocation.create!(
      plate: plates(:two),
      location: locations(:carousel_1_hotel_2),
      moved_at: earlier_time,
      moved_by: "test_user"
    )

    ordered = PlateLocation.ordered_by_date.to_a
    assert_equal earlier_location, ordered.first
    assert_equal later_location, ordered.last
  end

  test "recent_first scope should order by moved_at descending" do
    later_time = 1.hour.from_now
    earlier_time = 1.hour.ago

    later_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: later_time,
      moved_by: "test_user"
    )

    earlier_location = PlateLocation.create!(
      plate: plates(:two),
      location: locations(:carousel_1_hotel_2),
      moved_at: earlier_time,
      moved_by: "test_user"
    )

    ordered = PlateLocation.recent_first.to_a
    assert_equal later_location, ordered.first
    assert_equal earlier_location, ordered.last
  end

  test "should allow multiple plate_locations for same plate" do
    first_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: 1.hour.ago,
      moved_by: "test_user"
    )

    second_location = PlateLocation.create!(
      plate: @plate,
      location: locations(:imager),
      moved_at: Time.current,
      moved_by: "test_user"
    )

    assert first_location.persisted?
    assert second_location.persisted?
    assert_equal 2, @plate.plate_locations.count
  end

  test "should allow multiple plate_locations for same location at different times" do
    first_plate_location = PlateLocation.create!(
      plate: @plate,
      location: @location,
      moved_at: 1.hour.ago,
      moved_by: "test_user"
    )

    second_plate_location = PlateLocation.create!(
      plate: plates(:two),
      location: @location,
      moved_at: Time.current,
      moved_by: "test_user"
    )

    assert first_plate_location.persisted?
    assert second_plate_location.persisted?
    assert_equal 2, @location.plate_locations.count
  end
end
