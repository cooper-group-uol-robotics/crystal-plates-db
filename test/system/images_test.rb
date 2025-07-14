require "application_system_test_case"

class ImagesTest < ApplicationSystemTestCase
  setup do
    @plate = plates(:one)
    @well = wells(:one)
    @well.update!(plate: @plate) if @well.plate != @plate
  end

  test "visiting well shows image modal with no images initially" do
    visit plate_path(@plate)

    # Find the well button (should be red indicating no images)
    well_button = find("button[data-well-id='#{@well.id}']")

    # Check that it has the red background color (no images)
    button_style = well_button[:style]
    assert button_style.include?("background-color: rgb(220, 53, 69)") ||
           button_style.include?("background-color: #dc3545"),
           "Well button should be red (no images), but style was: #{button_style}"

    # Click the well button to open modal
    well_button.click

    # Modal should open and show no images
    assert_selector "#wellImagesModal", visible: true
    assert_text "No images attached to this well"
    assert_link "Add First Image"
  end

  test "can add new image with auto-detected dimensions" do
    visit plate_path(@plate)

    # Click well button to open modal
    find("button[data-well-id='#{@well.id}']").click

    # Click "Add First Image" link
    click_link "Add First Image"

    # Should be on new image page
    assert_current_path new_well_image_path(@well)
    assert_selector "h4", text: "Add Image to Well #{@well.well_label}"

    # Fill in the required spatial calibration fields
    fill_in "Pixel Size X (mm/pixel)", with: "0.001"
    fill_in "Pixel Size Y (mm/pixel)", with: "0.001"
    fill_in "Reference Point X (mm)", with: "10.0"
    fill_in "Reference Point Y (mm)", with: "10.0"
    fill_in "Reference Point Z (mm)", with: "5.0"

    # Create a test image file
    test_image_path = create_test_image

    # Attach the image file
    attach_file "Image File", test_image_path

    # Add description
    fill_in "Description", with: "Test microscopy image"

    # Submit the form
    click_button "Save Image"

    # Should redirect back to well (which redirects to plate)
    assert_current_path plate_path(@plate)
    assert_text "Image was successfully created"

    # Clean up test file
    File.delete(test_image_path) if File.exist?(test_image_path)
  end

  test "well button turns green after adding image" do
    # Create an image for the well first
    create_test_image_for_well

    visit plate_path(@plate)

    # Well button should now be green
    well_button = find("button[data-well-id='#{@well.id}']")
    button_style = well_button[:style]
    assert button_style.include?("background-color: rgb(25, 135, 84)") ||
           button_style.include?("background-color: #198754"),
           "Well button should be green (has images), but style was: #{button_style}"
  end

  test "can view image details in modal" do
    # Create an image for the well first
    image = create_test_image_for_well

    visit plate_path(@plate)

    # Click well button to open modal
    find("button[data-well-id='#{@well.id}']").click

    # Modal should show the image with metadata
    within "#wellImagesModal" do
      assert_text "Well Images (1)"
      assert_text "Test microscopy image"
      assert_text "#{image.pixel_width}×#{image.pixel_height}px"
      assert_text "#{sprintf('%.2f', image.physical_width_mm)}×#{sprintf('%.2f', image.physical_height_mm)}mm"
      assert_link "View"
      assert_link "Edit"
      assert_button "Delete"
    end
  end

  test "can view individual image page" do
    image = create_test_image_for_well

    visit plate_path(@plate)

    # Click well button and then view image
    find("button[data-well-id='#{@well.id}']").click

    within "#wellImagesModal" do
      click_link "View"
    end

    # Should be on image show page
    assert_current_path well_image_path(@well, image)
    assert_selector "h4", text: "Image for Well #{@well.well_label}"

    # Check that spatial data is displayed
    assert_text "#{image.pixel_width}×#{image.pixel_height} pixels"
    assert_text "#{sprintf('%.3f', image.physical_width_mm)}×#{sprintf('%.3f', image.physical_height_mm)} mm"
    assert_text "(#{sprintf('%.3f', image.reference_x_mm)}, #{sprintf('%.3f', image.reference_y_mm)}, #{sprintf('%.3f', image.reference_z_mm)})"
    assert_text "Test microscopy image"
  end

  test "can edit image metadata" do
    image = create_test_image_for_well

    visit well_image_path(@well, image)

    # Click edit button
    click_link "Edit"

    # Should be on edit page
    assert_current_path edit_well_image_path(@well, image)
    assert_selector "h4", text: "Edit Image for Well #{@well.well_label}"

    # Update description
    fill_in "Description", with: "Updated test image description"

    # Update reference coordinates
    fill_in "Reference Point X (mm)", with: "15.0"
    fill_in "Reference Point Y (mm)", with: "20.0"

    # Submit changes
    click_button "Save Image"

    # Should redirect to image show page
    assert_current_path well_image_path(@well, image)
    assert_text "Image was successfully updated"
    assert_text "Updated test image description"
    assert_text "(15.000, 20.000"
  end

  test "can delete image" do
    create_test_image_for_well

    visit plate_path(@plate)

    # Click well button to open modal
    find("button[data-well-id='#{@well.id}']").click

    # Delete the image
    within "#wellImagesModal" do
      accept_confirm do
        click_button "Delete"
      end
    end

    # Should redirect back to well/plate and show no images
    assert_current_path plate_path(@plate)
    assert_text "Image was successfully deleted"

    # Well button should be red again
    well_button = find("button[data-well-id='#{@well.id}']")
    button_style = well_button[:style]
    assert button_style.include?("background-color: rgb(220, 53, 69)") ||
           button_style.include?("background-color: #dc3545"),
           "Well button should be red again (no images), but style was: #{button_style}"
  end

  test "shows error when required fields are missing" do
    visit new_well_image_path(@well)

    # Try to submit without filling required fields
    click_button "Save Image"

    # Should stay on the same page and show validation errors
    assert_current_path well_images_path(@well)
    assert_text "prohibited this image from being saved"
    assert_text "can't be blank"
  end

  test "shows error when pixel sizes are invalid" do
    visit new_well_image_path(@well)

    # Fill in invalid pixel sizes
    fill_in "Pixel Size X (mm/pixel)", with: "0"
    fill_in "Pixel Size Y (mm/pixel)", with: "-1"
    fill_in "Reference Point X (mm)", with: "10.0"
    fill_in "Reference Point Y (mm)", with: "10.0"
    fill_in "Reference Point Z (mm)", with: "5.0"

    # Attach a test image
    test_image_path = create_test_image
    attach_file "Image File", test_image_path

    # Submit form
    click_button "Save Image"

    # Should show validation errors
    assert_text "Pixel size x mm must be greater than 0"
    assert_text "Pixel size y mm must be greater than 0"

    # Clean up
    File.delete(test_image_path) if File.exist?(test_image_path)
  end

  test "can manually specify pixel dimensions" do
    visit new_well_image_path(@well)

    # Fill in all fields including manual pixel dimensions
    fill_in "Pixel Size X (mm/pixel)", with: "0.001"
    fill_in "Pixel Size Y (mm/pixel)", with: "0.001"
    fill_in "Reference Point X (mm)", with: "10.0"
    fill_in "Reference Point Y (mm)", with: "10.0"
    fill_in "Reference Point Z (mm)", with: "5.0"
    fill_in "Image Width (pixels)", with: "2000"
    fill_in "Image Height (pixels)", with: "1500"

    # Attach a test image
    test_image_path = create_test_image
    attach_file "Image File", test_image_path

    # Submit form
    click_button "Save Image"

    # Should succeed and use manual dimensions
    assert_current_path plate_path(@plate)
    assert_text "Image was successfully created"

    # Check that manual dimensions were used
    image = @well.images.last
    assert_equal 2000, image.pixel_width
    assert_equal 1500, image.pixel_height

    # Clean up
    File.delete(test_image_path) if File.exist?(test_image_path)
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

  private

  def create_test_image
    # Create a simple test image file using a basic approach
    require "tempfile"
    require "base64"

    tempfile = Tempfile.new([ "test_image", ".png" ])

    # Write a minimal valid PNG file (1x1 transparent pixel)
    # This is a base64 decoded minimal PNG
    png_data = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAI/hxyku2UAAAAASUVORK5CYII=")

    tempfile.binmode
    tempfile.write(png_data)
    tempfile.close
    tempfile.path
  end

  def create_test_image_for_well
    # Create an image record for testing
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

    # Save the image
    image.save!

    # Clean up the temporary file
    File.delete(test_image_path) if File.exist?(test_image_path)

    image
  end
end
