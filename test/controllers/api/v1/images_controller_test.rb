require "test_helper"

module Api
  module V1
    class ImagesControllerTest < ActionDispatch::IntegrationTest
      setup do
        @plate = plates(:one)
        @well = wells(:one)
        @image = images(:one)

        # Ensure the well belongs to the plate for consistent test data
        @well.update!(plate: @plate) if @well.plate != @plate
        @image.update!(well: @well) if @image.well != @well

        # Attach a test file to the image fixture
        @image.file.attach(
          io: File.open(Rails.root.join("test", "fixtures", "files", "test_image.png")),
          filename: "test_image.png",
          content_type: "image/png"
        ) unless @image.file.attached?
      end

      test "should get index" do
        get api_v1_well_images_url(@well), as: :json

        assert_response :success

        json_response = JSON.parse(response.body)
        assert json_response.key?("data")
        assert_kind_of Array, json_response["data"]

        # Should include the test image
        image_ids = json_response["data"].map { |img| img["id"] }
        assert_includes image_ids, @image.id
      end

      test "should show image" do
        get api_v1_well_image_url(@well, @image), as: :json

        assert_response :success

        json_response = JSON.parse(response.body)
        assert json_response.key?("data")

        image_data = json_response["data"]
        assert_equal @image.id, image_data["id"]
        assert_in_delta @image.pixel_size_x_mm.to_f, image_data["pixel_size_x_mm"].to_f, 0.0001
        assert_in_delta @image.pixel_size_y_mm.to_f, image_data["pixel_size_y_mm"].to_f, 0.0001
        assert_in_delta @image.reference_x_mm.to_f, image_data["reference_x_mm"].to_f, 0.0001
        assert_in_delta @image.reference_y_mm.to_f, image_data["reference_y_mm"].to_f, 0.0001
        assert_in_delta @image.reference_z_mm.to_f, image_data["reference_z_mm"].to_f, 0.0001

        # Should include detailed information
        assert image_data.key?("pixel_width")
        assert image_data.key?("pixel_height")
        assert image_data.key?("physical_width_mm")
        assert image_data.key?("physical_height_mm")
        assert image_data.key?("bounding_box")
        assert image_data.key?("file_url")
        assert image_data.key?("created_at")
        assert image_data.key?("updated_at")
      end

      test "should create image with file upload" do
        # Create a test image file
        test_image = fixture_file_upload("test_image.png", "image/png")

        assert_difference("Image.count") do
          post api_v1_well_images_url(@well), params: {
            image: {
              file: test_image,
              pixel_size_x_mm: 0.1,
              pixel_size_y_mm: 0.1,
              reference_x_mm: 0.0,
              reference_y_mm: 0.0,
              reference_z_mm: 5.0,
              description: "Test image via API"
            }
          }
        end

        assert_response :created

        json_response = JSON.parse(response.body)
        assert json_response.key?("data")
        assert_equal "Image created successfully", json_response["message"]

        image_data = json_response["data"]
        assert_in_delta 0.1, image_data["pixel_size_x_mm"].to_f, 0.0001
        assert_in_delta 0.1, image_data["pixel_size_y_mm"].to_f, 0.0001
        assert_in_delta 0.0, image_data["reference_x_mm"].to_f, 0.0001
        assert_in_delta 0.0, image_data["reference_y_mm"].to_f, 0.0001
        assert_in_delta 5.0, image_data["reference_z_mm"].to_f, 0.0001
        assert_equal "Test image via API", image_data["description"]

        # Verify the image was associated with the correct well
        created_image = Image.find(image_data["id"])
        assert_equal @well, created_image.well
        assert created_image.file.attached?
      end

      test "should create image with auto-detected dimensions" do
        test_image = fixture_file_upload("test_image.png", "image/png")

        post api_v1_well_images_url(@well), params: {
          image: {
            file: test_image,
            pixel_size_x_mm: 0.2,
            pixel_size_y_mm: 0.2,
            reference_x_mm: 1.0,
            reference_y_mm: 2.0,
            reference_z_mm: 3.0
          }
        }

        assert_response :created

        json_response = JSON.parse(response.body)
        image_data = json_response["data"]

        # Dimensions should be auto-detected (will be set by after_commit callback)
        created_image = Image.find(image_data["id"])

        # Force the callback to run in test
        created_image.send(:populate_dimensions_if_needed)
        created_image.reload

        # Should have auto-detected dimensions if the test image has them
        assert created_image.pixel_width.present? || created_image.pixel_height.present?
      end

      test "should not create image without required fields" do
        assert_no_difference("Image.count") do
          post api_v1_well_images_url(@well), params: {
            image: {
              # Missing required fields
              description: "Invalid image"
            }
          }
        end

        assert_response :unprocessable_entity

        json_response = JSON.parse(response.body)
        assert json_response.key?("error")
        assert json_response.key?("details")
        assert_kind_of Array, json_response["details"]
      end

      test "should not create image without file" do
        assert_no_difference("Image.count") do
          post api_v1_well_images_url(@well), params: {
            image: {
              pixel_size_x_mm: 0.1,
              pixel_size_y_mm: 0.1,
              reference_x_mm: 0.0,
              reference_y_mm: 0.0,
              reference_z_mm: 5.0
              # Missing file
            }
          }
        end

        assert_response :unprocessable_entity

        json_response = JSON.parse(response.body)
        assert_includes json_response["details"], "File can't be blank"
      end

      test "should update image metadata" do
        # Ensure the image has a file attached before updating
        unless @image.file.attached?
          @image.file.attach(
            io: File.open(Rails.root.join("test", "fixtures", "files", "test_image.png")),
            filename: "test_image.png",
            content_type: "image/png"
          )
        end

        patch api_v1_well_image_url(@well, @image), params: {
          image: {
            pixel_size_x_mm: 0.05,
            pixel_size_y_mm: 0.05,
            reference_x_mm: 10.0,
            reference_y_mm: 20.0,
            reference_z_mm: 30.0,
            description: "Updated description"
          }
        }, as: :json

        assert_response :success

        json_response = JSON.parse(response.body)
        assert_equal "Image updated successfully", json_response["message"]

        image_data = json_response["data"]
        assert_in_delta 0.05, image_data["pixel_size_x_mm"].to_f, 0.0001
        assert_in_delta 0.05, image_data["pixel_size_y_mm"].to_f, 0.0001
        assert_in_delta 10.0, image_data["reference_x_mm"].to_f, 0.0001
        assert_in_delta 20.0, image_data["reference_y_mm"].to_f, 0.0001
        assert_in_delta 30.0, image_data["reference_z_mm"].to_f, 0.0001
        assert_equal "Updated description", image_data["description"]

        # Verify database was updated
        @image.reload
        assert_equal 0.05, @image.pixel_size_x_mm
        assert_equal "Updated description", @image.description
      end

      test "should not update image with invalid data" do
        patch api_v1_well_image_url(@well, @image), params: {
          image: {
            pixel_size_x_mm: -1, # Invalid negative value
            pixel_size_y_mm: 0.1,
            reference_x_mm: 0.0,
            reference_y_mm: 0.0,
            reference_z_mm: 5.0
          }
        }, as: :json

        assert_response :unprocessable_entity

        json_response = JSON.parse(response.body)
        assert json_response.key?("error")
        assert json_response.key?("details")
      end

      test "should destroy image" do
        assert_difference("Image.count", -1) do
          delete api_v1_well_image_url(@well, @image), as: :json
        end

        assert_response :success

        json_response = JSON.parse(response.body)
        assert_equal "Image deleted successfully", json_response["message"]
      end

      test "should return 404 for non-existent well" do
        non_existent_well_id = Well.maximum(:id).to_i + 1

        get api_v1_well_images_url(non_existent_well_id), as: :json

        assert_response :not_found
      end

      test "should return 404 for non-existent image" do
        non_existent_image_id = Image.maximum(:id).to_i + 1

        get api_v1_well_image_url(@well, non_existent_image_id), as: :json

        assert_response :not_found
      end

      test "should return 404 for image not belonging to well" do
        other_well = wells(:two)
        other_image = images(:two)

        # Ensure the other image belongs to the other well and has a file
        other_image.update!(well: other_well)
        other_image.file.attach(
          io: File.open(Rails.root.join("test", "fixtures", "files", "test_image.png")),
          filename: "test_image.png",
          content_type: "image/png"
        ) unless other_image.file.attached?

        get api_v1_well_image_url(@well, other_image), as: :json

        assert_response :not_found
      end

      test "index should handle well with no images" do
        # Create a well with no images
        empty_well = Well.create!(
          plate: @plate,
          well_row: 99,
          well_column: 99
        )

        get api_v1_well_images_url(empty_well), as: :json

        assert_response :success

        json_response = JSON.parse(response.body)
        assert json_response.key?("data")
        assert_equal [], json_response["data"]
      end

      test "should set captured_at to current time if not provided" do
        test_image = fixture_file_upload("test_image.png", "image/png")

        travel_to Time.parse("2025-07-15 10:00:00 UTC") do
          post api_v1_well_images_url(@well), params: {
            image: {
              file: test_image,
              pixel_size_x_mm: 0.1,
              pixel_size_y_mm: 0.1,
              reference_x_mm: 0.0,
              reference_y_mm: 0.0,
              reference_z_mm: 5.0
            }
          }

          assert_response :created

          json_response = JSON.parse(response.body)
          image_data = json_response["data"]

          # Should have set captured_at to current time
          expected_time = Time.current.iso8601
          actual_time = Time.parse(image_data["captured_at"]).iso8601
          assert_equal expected_time, actual_time
        end
      end

      test "should respect provided captured_at time" do
        test_image = fixture_file_upload("test_image.png", "image/png")
        custom_time = 1.hour.ago

        post api_v1_well_images_url(@well), params: {
          image: {
            file: test_image,
            pixel_size_x_mm: 0.1,
            pixel_size_y_mm: 0.1,
            reference_x_mm: 0.0,
            reference_y_mm: 0.0,
            reference_z_mm: 5.0,
            captured_at: custom_time.iso8601
          }
        }

        assert_response :created

        json_response = JSON.parse(response.body)
        image_data = json_response["data"]

        # Should have used the provided time
        expected_time = custom_time.iso8601
        actual_time = Time.parse(image_data["captured_at"]).iso8601
        assert_equal expected_time, actual_time
      end
    end
  end
end
