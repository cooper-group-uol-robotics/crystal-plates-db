require "test_helper"

class ImagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @well = wells(:one)
    @plate = plates(:one)
    @well.update!(plate: @plate)
  end

  test "should get new" do
    get new_well_image_url(@well)
    assert_response :success
    assert_select "h4", text: /Add Image to Well/
  end

  test "should create image with manual dimensions" do
    # Create a simple test file
    test_file = fixture_file_upload("test_image.png", "image/png")

    assert_difference("Image.count") do
      post well_images_url(@well), params: {
        image: {
          file: test_file,
          pixel_size_x_mm: 0.1,
          pixel_size_y_mm: 0.1,
          reference_x_mm: 0,
          reference_y_mm: 0,
          reference_z_mm: 0,
          pixel_width: 100,
          pixel_height: 100,
          description: "Test image"
        }
      }
    end

    image = Image.last
    assert_equal @well, image.well
    assert_equal 0.1, image.pixel_size_x_mm
    assert_equal 100, image.pixel_width
    assert_redirected_to plate_url(@well.plate)
  end

  test "should show image" do
    image = create_test_image
    get well_image_url(@well, image)
    assert_response :success
    assert_select "h4", text: /Image for Well/
  end

  test "should get edit" do
    image = create_test_image
    get edit_well_image_url(@well, image)
    assert_response :success
    assert_select "h4", text: /Edit Image for Well/
  end

  test "should update image" do
    image = create_test_image
    patch well_image_url(@well, image), params: {
      image: {
        description: "Updated description",
        pixel_size_x_mm: 0.2
      }
    }
    assert_redirected_to well_image_url(@well, image)

    image.reload
    assert_equal "Updated description", image.description
    assert_equal 0.2, image.pixel_size_x_mm
  end

  test "should destroy image" do
    image = create_test_image
    assert_difference("Image.count", -1) do
      delete well_image_url(@well, image)
    end
    assert_redirected_to @well.plate
  end

  test "should require file" do
    post well_images_url(@well), params: {
      image: {
        pixel_size_x_mm: 0.1,
        pixel_size_y_mm: 0.1,
        reference_x_mm: 0,
        reference_y_mm: 0,
        reference_z_mm: 0
      }
    }

    assert_response :unprocessable_entity
    assert_select ".alert", text: /error/
  end

  test "should require pixel sizes" do
    test_file = fixture_file_upload("test_image.png", "image/png")

    post well_images_url(@well), params: {
      image: {
        file: test_file,
        reference_x_mm: 0,
        reference_y_mm: 0,
        reference_z_mm: 0
      }
    }

    assert_response :unprocessable_entity
    assert_select ".alert", text: /error/
  end

  private

  def create_test_image
    test_file = fixture_file_upload("test_image.png", "image/png")

    Image.create!(
      well: @well,
      file: test_file,
      pixel_size_x_mm: 0.1,
      pixel_size_y_mm: 0.1,
      reference_x_mm: 0,
      reference_y_mm: 0,
      reference_z_mm: 0,
      pixel_width: 100,
      pixel_height: 100
    )
  end
end
