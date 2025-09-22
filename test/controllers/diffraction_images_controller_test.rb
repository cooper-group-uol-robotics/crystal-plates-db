require "test_helper"

class DiffractionImagesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get diffraction_images_index_url
    assert_response :success
  end

  test "should get show" do
    get diffraction_images_show_url
    assert_response :success
  end

  test "should get image_data" do
    get diffraction_images_image_data_url
    assert_response :success
  end

  test "should get download" do
    get diffraction_images_download_url
    assert_response :success
  end
end
