require "test_helper"

class PointOfInterestTest < ActiveSupport::TestCase
  def setup
    @image = images(:one)
    @point = point_of_interests(:crystal_one)
  end

  test "should be valid" do
    assert @point.valid?
  end

  test "should require pixel coordinates" do
    @point.pixel_x = nil
    assert_not @point.valid?
    assert_includes @point.errors[:pixel_x], "can't be blank"

    @point.pixel_x = 100
    @point.pixel_y = nil
    assert_not @point.valid?
    assert_includes @point.errors[:pixel_y], "can't be blank"
  end

  test "should require valid point type" do
    @point.point_type = nil
    assert_not @point.valid?
    assert_includes @point.errors[:point_type], "can't be blank"

    @point.point_type = "invalid_type"
    assert_not @point.valid?
    assert_includes @point.errors[:point_type], "is not included in the list"

    @point.point_type = "crystal"
    assert @point.valid?
  end

  test "should calculate real world coordinates" do
    # Assuming image has reference point and pixel size set
    @image.update!(
      reference_x_mm: 0.0,
      reference_y_mm: 0.0,
      reference_z_mm: 5.0,
      pixel_size_x_mm: 0.1,
      pixel_size_y_mm: 0.1
    )

    point = @image.point_of_interests.build(
      pixel_x: 100,
      pixel_y: 150,
      point_type: "crystal"
    )

    assert_equal 10.0, point.real_world_x_mm  # 0.0 + (100 * 0.1)
    assert_equal 15.0, point.real_world_y_mm  # 0.0 + (150 * 0.1)
    assert_equal 5.0, point.real_world_z_mm   # Same as image reference Z
  end

  test "should validate coordinates within image bounds" do
    @image.update!(pixel_width: 500, pixel_height: 400)

    point = @image.point_of_interests.build(
      pixel_x: 600,  # Beyond image width
      pixel_y: 200,
      point_type: "crystal"
    )

    assert_not point.valid?
    assert_includes point.errors[:pixel_x], "must be within image width (500 pixels)"

    point.pixel_x = 200
    point.pixel_y = 500  # Beyond image height
    assert_not point.valid?
    assert_includes point.errors[:pixel_y], "must be within image height (400 pixels)"
  end

  test "should have display name" do
    point = point_of_interests(:crystal_one)
    assert_includes point.display_name.downcase, "crystal"
    assert_includes point.display_name, point.description

    point_without_description = @image.point_of_interests.build(
      pixel_x: 100,
      pixel_y: 150,
      point_type: "particle"
    )
    assert_includes point_without_description.display_name, "Particle at (100, 150)"
  end

  test "should set default marked_at on create" do
    point = @image.point_of_interests.build(
      pixel_x: 100,
      pixel_y: 150,
      point_type: "crystal"
    )

    assert_nil point.marked_at
    point.valid?  # Triggers before_validation callback
    assert_not_nil point.marked_at
    assert_kind_of Time, point.marked_at
  end

  test "scopes should work correctly" do
    crystals = PointOfInterest.crystals
    assert_includes crystals, point_of_interests(:crystal_one)
    assert_includes crystals, point_of_interests(:crystal_two)
    assert_not_includes crystals, point_of_interests(:particle_one)

    particles = PointOfInterest.particles
    assert_includes particles, point_of_interests(:particle_one)
    assert_not_includes particles, point_of_interests(:crystal_one)
  end
end
