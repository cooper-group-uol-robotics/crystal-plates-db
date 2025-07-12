require "application_system_test_case"

class LocationsTest < ApplicationSystemTestCase
  setup do
    @carousel_location = locations(:carousel_1_hotel_1)
    @imager_location = locations(:imager)
    @plate1 = plates(:one)
    @plate2 = plates(:two)
  end

  test "visiting locations index" do
    visit locations_url

    assert_selector "h1", text: "Carousel Grid View"
    assert_selector ".carousel-grid"
    assert_selector "a", text: "New Location"

    # Should not have list view elements since it was removed
    assert_no_selector "table", text: "Location"
  end

  test "visiting grid view" do
    visit grid_locations_url

    assert_selector "h1", text: "Carousel Grid View"
    assert_selector ".carousel-grid"
    assert_selector ".grid-cell"
  end

  test "creating a new carousel location" do
    visit new_location_url

    assert_selector "h1", text: "Create New Location"

    # Select carousel type
    choose "Carousel/Hotel Position"

    # Fill in carousel and hotel positions
    fill_in "Carousel Position", with: 5
    fill_in "Hotel Position", with: 15

    click_on "Create Location"

    # Should redirect to the new location
    assert_current_path %r{/locations/\d+}
    assert_selector "h1", text: "Location: Carousel 5, Hotel 15"
  end

  test "creating a new special location" do
    visit new_location_url

    # Select special type
    choose "Special Location"

    # Fill in name
    fill_in "Name", with: "test_storage"

    click_on "Create Location"

    # Should redirect to the new location
    assert_current_path %r{/locations/\d+}
    assert_selector "h1", text: "Location: test_storage"
  end

  test "editing an existing location" do
    visit edit_location_url(@carousel_location)

    assert_selector "h1", text: "Edit Location"

    # Update the positions
    fill_in "Carousel Position", with: 3
    fill_in "Hotel Position", with: 7

    click_on "Update Location"

    # Should redirect to the location
    assert_current_path location_path(@carousel_location)
    assert_selector "h1", text: "Location: Carousel 3, Hotel 7"
  end

  test "deleting an empty location" do
    # Create a new location for testing deletion
    empty_location = Location.create!(name: "test_delete_location")

    visit location_url(empty_location)

    # Click delete without confirmation handling for now
    click_on "Delete"

    # Should redirect to grid view
    assert_current_path grid_locations_path
    assert_selector ".alert-success", text: "Location was successfully deleted"
  end

  test "cannot delete occupied location" do
    # Move a plate to the location
    @plate1.move_to_location!(@imager_location)

    visit location_url(@imager_location)

    # Click delete without confirmation handling for now
    click_on "Delete"

    # Should stay on grid view with error message
    assert_current_path grid_locations_path
    assert_selector ".alert-danger", text: "Cannot delete location that currently contains plates"
  end

  test "grid view shows occupied and available locations" do
    # Move a plate to a location
    @plate1.move_to_location!(@carousel_location)

    visit grid_locations_url

    # Should have both occupied and available cells
    assert_selector ".grid-cell.occupied"
    assert_selector ".grid-cell.available"

    # Should show plate barcode in occupied cell
    assert_selector ".grid-cell.occupied", text: @plate1.barcode
  end

  test "location form shows both field sets" do
    visit new_location_url

    # Both carousel and special location fields should be visible
    assert_selector "input[name='location[carousel_position]']"
    assert_selector "input[name='location[hotel_position]']"
    assert_selector "input[name='location[name]']"

    # Radio buttons should be present
    assert_selector "input[name='location_type'][value='carousel']"
    assert_selector "input[name='location_type'][value='special']"
  end

  test "location show page displays current plates and history" do
    # Move plate to location and then move it away
    @plate1.move_to_location!(@carousel_location)
    @plate1.move_to_location!(@imager_location)

    visit location_url(@carousel_location)

    # Should show no current plates
    assert_selector "h3", text: "Current Plates"
    assert_selector "p", text: "No plates currently at this location"

    # Should show history
    assert_selector "h3", text: "Location History"
    assert_selector "table"
    assert_selector "td", text: @plate1.barcode
  end
end
