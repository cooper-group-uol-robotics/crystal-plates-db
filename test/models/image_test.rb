require "test_helper"

class ImageTest < ActiveSupport::TestCase
  def setup
    @well = wells(:one)
    @image = Image.new(
      well: @well,
      pixel_size_x_mm: 0.001,
      pixel_size_y_mm: 0.001,
      reference_x_mm: 10.0,
      reference_y_mm: 20.0,
      reference_z_mm: 5.0,
      pixel_width: 1000,
      pixel_height: 800,
      captured_at: Time.current
    )

    # Create a sample image file for testing
    @image.file.attach(
      io: StringIO.new("fake image data"),
      filename: "test_image.jpg",
      content_type: "image/jpeg"
    )
  end

  test "should be valid with valid attributes" do
    assert @image.valid?
  end

  test "should require well" do
    @image.well = nil
    assert_not @image.valid?
    assert_includes @image.errors[:well], "must exist"
  end

  test "should require pixel sizes" do
    @image.pixel_size_x_mm = nil
    @image.pixel_size_y_mm = nil
    assert_not @image.valid?
    assert_includes @image.errors[:pixel_size_x_mm], "can't be blank"
    assert_includes @image.errors[:pixel_size_y_mm], "can't be blank"
  end

  test "should require positive pixel sizes" do
    @image.pixel_size_x_mm = 0
    @image.pixel_size_y_mm = -1
    assert_not @image.valid?
    assert_includes @image.errors[:pixel_size_x_mm], "must be greater than 0"
    assert_includes @image.errors[:pixel_size_y_mm], "must be greater than 0"
  end

  test "should require reference coordinates" do
    @image.reference_x_mm = nil
    @image.reference_y_mm = nil
    @image.reference_z_mm = nil
    assert_not @image.valid?
    assert_includes @image.errors[:reference_x_mm], "can't be blank"
    assert_includes @image.errors[:reference_y_mm], "can't be blank"
    assert_includes @image.errors[:reference_z_mm], "can't be blank"
  end

  test "should require attached file" do
    @image.file.purge
    assert_not @image.valid?
    assert_includes @image.errors[:file], "can't be blank"
  end

  test "should calculate physical dimensions correctly" do
    assert_equal 1.0, @image.physical_width_mm
    assert_equal 0.8, @image.physical_height_mm
  end

  test "should calculate bounding box correctly" do
    bbox = @image.bounding_box
    assert_equal 10.0, bbox[:min_x]
    assert_equal 20.0, bbox[:min_y]
    assert_equal 11.0, bbox[:max_x]
    assert_equal 20.8, bbox[:max_y]
    assert_equal 5.0, bbox[:z]
  end

  test "should convert pixel coordinates to real world coordinates" do
    coords = @image.pixel_to_mm(500, 400)
    assert_equal 10.5, coords[:x]
    assert_equal 20.4, coords[:y]
    assert_equal 5.0, coords[:z]
  end

  test "should convert real world coordinates to pixel coordinates" do
    coords = @image.mm_to_pixel(10.5, 20.4)
    assert_equal 500, coords[:x]
    assert_equal 400, coords[:y]
  end

  test "should check if point is contained within image" do
    assert @image.contains_point?(10.5, 20.4)
    assert_not @image.contains_point?(9.0, 20.0)
    assert_not @image.contains_point?(12.0, 20.0)
  end
end
