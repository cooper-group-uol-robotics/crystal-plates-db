require "application_system_test_case"

class ImagesBasicTest < ApplicationSystemTestCase
  setup do
    @plate = plates(:one)
    @well = wells(:one)
    @well.update!(plate: @plate) if @well.plate != @plate
  end

  test "can access new image form" do
    visit new_well_image_path(@well)

    assert_selector "h4", text: "Add Image to Well #{@well.well_label}"
    assert_field "Pixel Size X (mm/pixel)"
    assert_field "Pixel Size Y (mm/pixel)"
    assert_field "Reference Point X (mm)"
    assert_field "Reference Point Y (mm)"
    assert_field "Reference Point Z (mm)"
    assert_field "Image Width (pixels)"
    assert_field "Image Height (pixels)"
    assert_field "Description"
    assert_button "Save Image"
  end

  test "form shows helpful information about auto-detection" do
    visit new_well_image_path(@well)

    # Check for informational alert
    assert_selector ".alert-info", text: "Image Dimensions"
    assert_text "automatically detected from your uploaded image file"

    # Check for placeholder text
    width_field = find_field("Image Width (pixels)")
    height_field = find_field("Image Height (pixels)")
    assert_equal "Auto-detected from file", width_field[:placeholder]
    assert_equal "Auto-detected from file", height_field[:placeholder]
  end

  test "shows validation errors when required fields are missing" do
    visit new_well_image_path(@well)

    # Try to submit without filling required fields
    click_button "Save Image"

    # Should show validation errors
    assert_text "prohibited this image from being saved"
    assert_text "can't be blank"
  end

  test "can create image with manual pixel dimensions" do
    visit new_well_image_path(@well)

    # Fill in all required fields
    fill_in "Pixel Size X (mm/pixel)", with: "0.001"
    fill_in "Pixel Size Y (mm/pixel)", with: "0.001"
    fill_in "Reference Point X (mm)", with: "10.0"
    fill_in "Reference Point Y (mm)", with: "10.0"
    fill_in "Reference Point Z (mm)", with: "5.0"
    fill_in "Image Width (pixels)", with: "1000"
    fill_in "Image Height (pixels)", with: "800"
    fill_in "Description", with: "Test image"

    # Attach a test image
    test_image_path = create_test_image
    attach_file "Image File", test_image_path

    # Submit form
    click_button "Save Image"

    # Should redirect with success message
    assert_text "Image was successfully created"

    # Check that the image was created with correct dimensions
    image = @well.images.last
    assert_equal 1000, image.pixel_width
    assert_equal 800, image.pixel_height
    assert_equal "Test image", image.description

    # Clean up
    File.delete(test_image_path) if File.exist?(test_image_path)
  end

  test "well has_images method works correctly" do
    # Initially no images
    assert_not @well.has_images?

    # Create an image
    create_test_image_for_well

    # Now should have images
    @well.reload
    assert @well.has_images?
  end

  test "can view image details when image exists" do
    image = create_test_image_for_well

    visit well_image_path(@well, image)

    assert_selector "h4", text: "Image for Well #{@well.well_label}"
    assert_text "#{image.pixel_width}×#{image.pixel_height} pixels"
    assert_text "Test microscopy image"
    assert_link "Edit"
    assert_button "Delete"
  end

  private

  def create_test_image
    require "tempfile"
    require "base64"

    tempfile = Tempfile.new([ "test_image", ".png" ])

    # Simple 1x1 PNG file
    png_data = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI/hzyku6UAAAAASUVORK5CYII=")

    tempfile.binmode
    tempfile.write(png_data)
    tempfile.close
    tempfile.path
  end

  def create_test_image_for_well
    image = @well.images.build(
      pixel_size_x_mm: 0.001,
      pixel_size_y_mm: 0.001,
      reference_x_mm: 10.0,
      reference_y_mm: 10.0,
      reference_z_mm: 5.0,
      pixel_width: 1000,
      pixel_height: 800,
      description: "Test microscopy image",
      captured_at: 1.hour.ago
    )

    # Create and attach a test file
    test_image_path = create_test_image
    image.file.attach(
      io: File.open(test_image_path, "rb"),
      filename: "test_image.png",
      content_type: "image/png"
    )

    image.save!

    # Clean up the temporary file
    File.delete(test_image_path) if File.exist?(test_image_path)

    image
  end
end
