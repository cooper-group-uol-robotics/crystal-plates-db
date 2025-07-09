require "application_system_test_case"

class WellsTest < ApplicationSystemTestCase
  setup do
    @well = wells(:one)
  end

  test "visiting the index" do
    visit wells_url
    assert_selector "h1", text: "Wells"
  end

  test "should create well" do
    visit wells_url
    click_on "New well"

    fill_in "Column", with: @well.column
    fill_in "Plate", with: @well.plate_id
    fill_in "Row", with: @well.row
    click_on "Create Well"

    assert_text "Well was successfully created"
    click_on "Back"
  end

  test "should update Well" do
    visit well_url(@well)
    click_on "Edit this well", match: :first

    fill_in "Column", with: @well.column
    fill_in "Plate", with: @well.plate_id
    fill_in "Row", with: @well.row
    click_on "Update Well"

    assert_text "Well was successfully updated"
    click_on "Back"
  end

  test "should destroy Well" do
    visit well_url(@well)
    click_on "Destroy this well", match: :first

    assert_text "Well was successfully destroyed"
  end
end
