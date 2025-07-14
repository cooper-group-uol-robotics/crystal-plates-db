require "application_system_test_case"

class ImagesSimpleTest < ApplicationSystemTestCase
  setup do
    @location = locations(:imager)
    @plate = plates(:one)
    @well = wells(:one)
    @well.update!(plate: @plate)
  end

  test "visiting plate shows well buttons for images modal" do
    visit plate_url(@plate)

    # Should have well buttons in a grid
    assert_selector "button[data-bs-toggle='modal'][data-bs-target='#wellImagesModal']"

    # Find the specific well button and click it
    well_button = find("button[data-well-id='#{@well.id}']")
    assert well_button.present?

    # Click the well button to open modal
    well_button.click

    # Modal should appear
    within "#wellImagesModal" do
      assert_text "Well Images"
    end
  end

  test "can navigate to new image form from plate" do
    visit plate_url(@plate)

    # Find the specific well button and click it
    well_button = find("button[data-well-id='#{@well.id}']")
    well_button.click

    # Wait for modal content to load then find the Add Image link
    assert_text "Well Images", wait: 5
    click_link "Add Image"

    # Should be on the new image form
    assert_current_path new_well_image_path(@well)
    assert_text "Add Image to Well"
    assert_text @well.name
    assert_text @plate.barcode
  end

  test "new image form has all required fields" do
    visit new_well_image_path(@well)

    # Check for all the required form fields
    assert_field "Pixel Size X (mm/pixel)"
    assert_field "Pixel Size Y (mm/pixel)"
    assert_field "Reference Point X (mm)"
    assert_field "Reference Point Y (mm)"
    assert_field "Reference Point Z (mm)"
    assert_field "Image File"

    # Optional fields
    assert_field "Image Width (pixels)"
    assert_field "Image Height (pixels)"
    assert_field "Capture Time"
    assert_field "Description"
  end

  test "form shows validation errors for required fields" do
    visit new_well_image_path(@well)

    # Submit form without filling required fields
    click_button "Create Image"

    # Should stay on the same page and show errors
    assert_current_path well_images_path(@well)
    assert_text "error"
  end

  test "well button shows correct color when no images exist" do
    visit plate_url(@plate)

    # Find the well button
    well_button = find("button[data-well-id='#{@well.id}']")
    button_style = well_button[:style]

    # Should be red/danger color when no images
    assert_includes button_style, "background-color: rgb(220, 53, 69)", "Well button should be red when no images exist"
  end

  test "can cancel from new image form" do
    visit new_well_image_path(@well)

    click_link "Cancel"

    # Should redirect back to well page
    assert_current_path well_path(@well)
  end

  test "can go back to well from new image form" do
    visit new_well_image_path(@well)

    click_link "Back to Well"

    # Should redirect back to well page
    assert_current_path well_path(@well)
  end
end
