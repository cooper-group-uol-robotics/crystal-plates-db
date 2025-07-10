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

    assert_selector "h1", text: "Location Management"
    assert_selector "table"
    assert_selector "a", text: "Grid View"
    assert_selector "a", text: "New Location"
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

    # Accept the confirmation dialog
    accept_confirm do
      click_on "Delete"
    end

    # Should redirect to locations index
    assert_current_path locations_path
    assert_selector ".alert-success", text: "Location was successfully deleted"
  end

  test "cannot delete occupied location" do
    # Move a plate to the location
    @plate1.move_to_location!(@imager_location, moved_by: "system_test")

    visit location_url(@imager_location)

    # Accept the confirmation dialog
    accept_confirm do
      click_on "Delete"
    end

    # Should stay on locations index with error message
    assert_current_path locations_path
    assert_selector ".alert-danger", text: "Cannot delete location that currently contains plates"
  end

  test "grid view shows occupied and available locations" do
    # Move a plate to a location
    @plate1.move_to_location!(@carousel_location, moved_by: "system_test")

    visit grid_locations_url

    # Should have both occupied and available cells
    assert_selector ".grid-cell.occupied"
    assert_selector ".grid-cell.available"

    # Should show plate barcode in occupied cell
    assert_selector ".grid-cell.occupied", text: @plate1.barcode
  end

  test "location form fields enable/disable based on type selection" do
    visit new_location_url

    # Initially, carousel should be selected and fields should be enabled
    assert_selector "input[name='location[carousel_position]']:not([disabled])"
    assert_selector "input[name='location[hotel_position]']:not([disabled])"
    assert_selector "input[name='location[name]'][disabled]"

    # Switch to special location
    choose "Special Location"

    # Wait for JavaScript to update the form
    sleep 0.1

    # Now carousel fields should be disabled and name enabled
    assert_selector "input[name='location[carousel_position]'][disabled]"
    assert_selector "input[name='location[hotel_position]'][disabled]"
    assert_selector "input[name='location[name]']:not([disabled])"
  end

  test "location show page displays current plates and history" do
    # Move plate to location and then move it away
    @plate1.move_to_location!(@carousel_location, moved_by: "system_test")
    @plate1.move_to_location!(@imager_location, moved_by: "system_test")

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
