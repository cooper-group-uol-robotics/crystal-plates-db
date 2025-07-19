require "test_helper"

class WellsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @well = wells(:one)
  end

  test "should get index" do
    get wells_url
    assert_response :success
  end

  test "should get new" do
    get new_well_url
    assert_response :success
  end

  test "should create well" do
    assert_difference("Well.count") do
      post wells_url, params: { well: { well_column: 2, plate_id: @well.plate_id, well_row: 2, subwell: 1 } }
    end

    assert_redirected_to @well.plate
  end

  test "should show well" do
    get well_url(@well)
    assert_response :success
  end

  test "should get edit" do
    get edit_well_url(@well)
    assert_response :success
  end

  test "should update well" do
    patch well_url(@well), params: { well: { well_column: @well.well_column, plate_id: @well.plate_id, well_row: @well.well_row, subwell: @well.subwell } }
    assert_redirected_to @well.plate
  end

  test "should destroy well" do
    assert_difference("Well.count", -1) do
      delete well_url(@well)
    end

    assert_redirected_to @well.plate
  end
end
