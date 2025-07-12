require "application_system_test_case"

class PlatesTest < ApplicationSystemTestCase
  setup do
    @plate = plates(:one)
    @location = locations(:carousel_1_hotel_1)
  end

  test "visiting the index shows sortable table" do
    visit plates_url
    assert_selector "h1", text: "Plates"
    assert_selector "table"
    assert_selector "th", text: "Barcode"
    assert_selector "th", text: "Current Location"
    assert_selector "th", text: "Created At"
    assert_selector "th", text: "Actions"
  end

  test "should create plate" do
    visit plates_url
    click_on "New plate"

    fill_in "Barcode", with: "UNIQUE_BARCODE_123"
    click_on "Create Plate"

    assert_text "Plate was successfully created"
    assert_selector "h1", text: "Plate: UNIQUE_BARCODE_123"
  end

  test "should update Plate" do
    visit plate_url(@plate)
    click_on "Edit this plate", match: :first

    fill_in "Barcode", with: "UPDATED_BARCODE"
    click_on "Update Plate"

    assert_text "Plate was successfully updated"
    assert_selector "h1", text: "Plate: UPDATED_BARCODE"
  end

  test "should destroy Plate" do
    visit plate_url(@plate)
    click_on "Destroy this plate", match: :first

    assert_text "Plate was successfully destroyed"
  end

  test "should sort plates by barcode" do
    # Create test plates with different barcodes
    Plate.create!(barcode: "AAAA")
    Plate.create!(barcode: "ZZZZ")

    visit plates_url

    # Default sorting should be barcode ascending
    first_row = find("tbody tr:first-child")
    assert first_row.has_text?("AAAA")

    # Click on barcode header to sort descending
    click_on "Barcode"

    # Should now show ZZZZ first
    first_row = find("tbody tr:first-child")
    assert first_row.has_text?("ZZZZ")
  end

  test "table shows current location for plates" do
    # Move plate to location
    @plate.move_to_location!(@location)

    visit plates_url

    # Should show location in the table
    plate_row = find("tr", text: @plate.barcode)
    assert plate_row.has_text?(@location.display_name)
  end

  test "table shows all action buttons on one line" do
    visit plates_url

    # Find a plate row and check that all buttons are present
    plate_row = find("tbody tr:first-child")
    within(plate_row) do
      assert_selector "a", text: "Show"
      assert_selector "a", text: "Edit"
      assert_selector "button", text: "Delete"
    end
  end
end
