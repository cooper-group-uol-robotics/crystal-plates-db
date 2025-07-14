require "application_system_test_case"

class ImagesFunctionalTest < ApplicationSystemTestCase
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
    assert_selector ".alert-info"
    assert_text "automatically detected from your uploaded image file"

    # Check for placeholder text
    width_field = find_field("Image Width (pixels)")
    height_field = find_field("Image Height (pixels)")
    assert_equal "Auto-detected from file", width_field[:placeholder]
    assert_equal "Auto-detected from file", height_field[:placeholder]
  end

  test "can create image with all manual fields" do
    visit new_well_image_path(@well)

    # Fill in all required fields including manual pixel dimensions
    fill_in "Pixel Size X (mm/pixel)", with: "0.001"
    fill_in "Pixel Size Y (mm/pixel)", with: "0.001"
    fill_in "Reference Point X (mm)", with: "10.0"
    fill_in "Reference Point Y (mm)", with: "10.0"
    fill_in "Reference Point Z (mm)", with: "5.0"
    fill_in "Image Width (pixels)", with: "1000"
    fill_in "Image Height (pixels)", with: "800"
    fill_in "Description", with: "Test image"

    # Create a test image file without using image processing
    test_image_path = create_simple_test_file
    attach_file "Image File", test_image_path

    # Submit form
    click_button "Save Image"

    # Should redirect with success message
    assert_text "Image was successfully created"

    # Verify the image was created with correct data
    image = @well.images.last
    assert_equal 1000, image.pixel_width
    assert_equal 800, image.pixel_height
    assert_equal 0.001, image.pixel_size_x_mm.to_f
    assert_equal "Test image", image.description
    assert image.file.attached?

    # Clean up
    File.delete(test_image_path) if File.exist?(test_image_path)
  end

  test "image model calculations work correctly" do
    image = create_simple_image_record

    # Test physical dimension calculations
    assert_equal 1.0, image.physical_width_mm  # 1000 * 0.001
    assert_equal 0.8, image.physical_height_mm # 800 * 0.001

    # Test coordinate conversion
    real_coords = image.pixel_to_mm(500, 400)
    assert_equal 10.5, real_coords[:x]  # 10.0 + (500 * 0.001)
    assert_equal 10.4, real_coords[:y]  # 10.0 + (400 * 0.001)
    assert_equal 5.0, real_coords[:z]

    # Test bounding box
    bbox = image.bounding_box
    assert_equal 10.0, bbox[:min_x]
    assert_equal 10.0, bbox[:min_y]
    assert_equal 11.0, bbox[:max_x]  # 10.0 + 1.0
    assert_equal 10.8, bbox[:max_y]  # 10.0 + 0.8
    assert_equal 5.0, bbox[:z]
  end

  test "well has_images method works correctly" do
    # Initially no images
    assert_not @well.has_images?

    # Create an image
    create_simple_image_record

    # Now should have images
    @well.reload
    assert @well.has_images?

    # Test latest_image method
    assert_not_nil @well.latest_image
    assert_equal "Test image", @well.latest_image.description
  end

  test "can view image details when image exists" do
    image = create_simple_image_record

    visit well_image_path(@well, image)

    assert_selector "h4", text: "Image for Well #{@well.well_label}"
    assert_text "#{image.pixel_width}×#{image.pixel_height} pixels"
    assert_text "Test image"
    assert_link "Edit"
    assert_button "Delete"
  end

  test "can edit image metadata" do
    image = create_simple_image_record

    visit edit_well_image_path(@well, image)

    assert_selector "h4", text: "Edit Image for Well #{@well.well_label}"

    # Update description and coordinates
    fill_in "Description", with: "Updated test description"
    fill_in "Reference Point X (mm)", with: "15.0"

    click_button "Save Image"

    # Should redirect to show page
    assert_current_path well_image_path(@well, image)
    assert_text "Image was successfully updated"
    assert_text "Updated test description"
  end

  test "can delete image" do
    image = create_simple_image_record

    visit well_image_path(@well, image)

    accept_confirm do
      click_button "Delete"
    end

    # Should redirect to well (which redirects to plate)
    assert_text "Image was successfully deleted"

    # Image should be deleted
    assert_not Image.exists?(image.id)
  end

  private

  def create_simple_test_file
    require "tempfile"

    # Create a simple text file that we'll treat as an image for testing
    tempfile = Tempfile.new([ "test_image", ".txt" ])
    tempfile.write("fake image data")
    tempfile.close
    tempfile.path
  end

  def create_simple_image_record
    # Create an image record for testing without image processing
    image = @well.images.build(
      pixel_size_x_mm: 0.001,
      pixel_size_y_mm: 0.001,
      reference_x_mm: 10.0,
      reference_y_mm: 10.0,
      reference_z_mm: 5.0,
      pixel_width: 1000,
      pixel_height: 800,
      description: "Test image",
      captured_at: 1.hour.ago
    )

    # Create a simple test file and attach it
    test_file_path = create_simple_test_file
    image.file.attach(
      io: File.open(test_file_path, "rb"),
      filename: "test_image.txt",
      content_type: "text/plain"  # Use a simple content type
    )

    image.save!

    # Clean up the temporary file
    File.delete(test_file_path) if File.exist?(test_file_path)

    image
  end
end
