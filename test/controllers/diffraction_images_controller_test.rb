require "test_helper"

class DiffractionImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @scxrd_dataset = scxrd_datasets(:one)
    @diffraction_image = diffraction_images(:one)
  end

  test "should get index" do
    get scxrd_dataset_diffraction_images_url(@scxrd_dataset)
    assert_response :success
  end

  test "should get show" do
    get scxrd_dataset_diffraction_image_url(@scxrd_dataset, @diffraction_image)
    assert_response :success
  end

  test "should handle image_data without attached file" do
    get image_data_scxrd_dataset_diffraction_image_url(@scxrd_dataset, @diffraction_image), 
        as: :json
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal false, response_data["success"]
    assert_equal "No rodhypix file attached", response_data["error"]
  end

  test "should handle download without attached file" do
    get download_scxrd_dataset_diffraction_image_url(@scxrd_dataset, @diffraction_image),
        as: :json
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_equal false, response_data["success"]
    assert_equal "No rodhypix file attached", response_data["error"]
  end
end
