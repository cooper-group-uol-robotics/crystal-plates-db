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
      post wells_url, params: { well: { column: @well.column, plate_id: @well.plate_id, row: @well.row } }
    end

    assert_redirected_to well_url(Well.last)
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
    patch well_url(@well), params: { well: { column: @well.column, plate_id: @well.plate_id, row: @well.row } }
    assert_redirected_to well_url(@well)
  end

  test "should destroy well" do
    assert_difference("Well.count", -1) do
      delete well_url(@well)
    end

    assert_redirected_to wells_url
  end
end
