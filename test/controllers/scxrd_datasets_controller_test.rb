require "test_helper"

class ScxrdDatasetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @plate = plates(:one)
    @well = wells(:one)
    @scxrd_dataset = scxrd_datasets(:one)
  end

  test "should get index" do
    get well_scxrd_datasets_path(@well)
    assert_response :success
  end

  test "should show scxrd_dataset" do
    get scxrd_dataset_path(@scxrd_dataset)
    assert_response :success
  end
end
