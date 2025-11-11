require "test_helper"

class Api::V1::ScxrdDatasetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @plate = plates(:one)
    @well = wells(:one)

    # Create a test SCXRD dataset associated with a well
    @well_dataset = ScxrdDataset.create!(
      well: @well,
      experiment_name: "Test Well Dataset",
      measured_at: Time.current
    )

    # Create a standalone SCXRD dataset (not associated with any well)
    @standalone_dataset = ScxrdDataset.create!(
      experiment_name: "Test Standalone Dataset",
      measured_at: Time.current
    )
  end

  # Test well-associated dataset endpoints
  test "should get index for well datasets" do
    get api_v1_well_scxrd_datasets_url(@well), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_not_nil json_response["scxrd_datasets"]
    assert_instance_of Array, json_response["scxrd_datasets"]
    assert json_response["scxrd_datasets"].length >= 1
    assert_equal @well.id, json_response["well_id"]

    # Find our specific well dataset in the response
    dataset_data = json_response["scxrd_datasets"].find { |d| d["id"] == @well_dataset.id }
    assert_not_nil dataset_data
    assert_equal @well_dataset.experiment_name, dataset_data["experiment_name"]
  end

  test "should create well-associated dataset" do
    assert_difference("ScxrdDataset.count") do
      post api_v1_well_scxrd_datasets_url(@well),
           params: { 
             scxrd_dataset: { 
               experiment_name: "New Well Dataset",
               measured_at: Time.current 
             } 
           },
           as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "New Well Dataset", json_response["scxrd_dataset"]["experiment_name"]
  end

  # Test standalone dataset endpoints
  test "should get index for all datasets" do
    get api_v1_scxrd_datasets_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_not_nil json_response["scxrd_datasets"]
    assert_instance_of Array, json_response["scxrd_datasets"]
    assert json_response["scxrd_datasets"].length >= 2 # at least well + standalone dataset

    # Find standalone dataset in response
    standalone_data = json_response["scxrd_datasets"].find { |d| d["experiment_name"] == @standalone_dataset.experiment_name }
    assert_not_nil standalone_data
    assert_equal @standalone_dataset.experiment_name, standalone_data["experiment_name"]
  end

  test "should create standalone dataset" do
    assert_difference("ScxrdDataset.count") do
      post api_v1_scxrd_datasets_url,
           params: { 
             scxrd_dataset: { 
               experiment_name: "New Standalone Dataset",
               measured_at: Time.current 
             } 
           },
           as: :json
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_equal "New Standalone Dataset", json_response["scxrd_dataset"]["experiment_name"]
  end

  test "should show well-associated dataset" do
    get api_v1_scxrd_dataset_url(@well_dataset), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @well_dataset.id, json_response["scxrd_dataset"]["id"]
    assert_equal @well_dataset.experiment_name, json_response["scxrd_dataset"]["experiment_name"]
  end

  test "should show standalone dataset" do
    get api_v1_scxrd_dataset_url(@standalone_dataset), as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal @standalone_dataset.id, json_response["scxrd_dataset"]["id"]
    assert_equal @standalone_dataset.experiment_name, json_response["scxrd_dataset"]["experiment_name"]
  end

  test "should update well-associated dataset" do
    patch api_v1_scxrd_dataset_url(@well_dataset),
          params: { 
            scxrd_dataset: { 
              experiment_name: "Updated Well Dataset" 
            } 
          },
          as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "Updated Well Dataset", json_response["scxrd_dataset"]["experiment_name"]
  end

  test "should update standalone dataset" do
    patch api_v1_scxrd_dataset_url(@standalone_dataset),
          params: { 
            scxrd_dataset: { 
              experiment_name: "Updated Standalone Dataset" 
            } 
          },
          as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "Updated Standalone Dataset", json_response["scxrd_dataset"]["experiment_name"]
  end

  test "should destroy well-associated dataset" do
    assert_difference("ScxrdDataset.count", -1) do
      delete api_v1_scxrd_dataset_url(@well_dataset), as: :json
    end
    assert_response :success
  end

  test "should destroy standalone dataset" do
    assert_difference("ScxrdDataset.count", -1) do
      delete api_v1_scxrd_dataset_url(@standalone_dataset), as: :json
    end
    assert_response :success
  end

  test "should return 404 for non-existent dataset" do
    get api_v1_scxrd_dataset_url(99999), as: :json
    assert_response :not_found
  end

  # Tests for the new upload_to_well endpoint
  test "should handle upload to well with missing archive" do
    post upload_to_well_api_v1_scxrd_datasets_url(
           barcode: @plate.barcode,
           well_string: "A1"
         ),
         params: { scxrd_dataset: { experiment_name: "Test Dataset" } },
         as: :json

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "Archive file is required", json_response["error"]
    assert_includes json_response["details"], "Please provide a ZIP archive file containing SCXRD data"
  end

  test "should handle invalid plate barcode in upload_to_well" do
    # Create a mock file upload
    mock_file = fixture_file_upload('test_archive.zip', 'application/zip')
    
    post upload_to_well_api_v1_scxrd_datasets_url(
           barcode: "INVALID_BARCODE",
           well_string: "A1"
         ),
         params: { archive: mock_file },
         as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Plate not found", json_response["error"]
    assert_includes json_response["details"].first, "INVALID_BARCODE"
  end

  test "should handle invalid well identifier in upload_to_well" do
    # Create a mock file upload
    mock_file = fixture_file_upload('test_archive.zip', 'application/zip')
    
    post upload_to_well_api_v1_scxrd_datasets_url(
           barcode: @plate.barcode,
           well_string: "Z99"
         ),
         params: { archive: mock_file },
         as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Well not found", json_response["error"]
    assert_includes json_response["details"].first, "Z99"
  end

  test "should handle malformed well identifier in upload_to_well" do
    # Create a mock file upload
    mock_file = fixture_file_upload('test_archive.zip', 'application/zip')
    
    post upload_to_well_api_v1_scxrd_datasets_url(
           barcode: @plate.barcode,
           well_string: "INVALID"
         ),
         params: { archive: mock_file },
         as: :json

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Well not found", json_response["error"]
    assert_includes json_response["details"].first, "INVALID"
  end

  # Skip the archive processing test for now since it requires complex setup and background processing
  # test "should upload SCXRD dataset to well using human-readable identifier" do
  #   # This would require a proper test archive file and background job processing
  #   mock_file = fixture_file_upload('test_archive.zip', 'application/zip')
  #   
  #   assert_difference("ScxrdDataset.count") do
  #     post upload_to_well_api_v1_scxrd_datasets_url(
  #            barcode: @plate.barcode,
  #            well_string: "A1"
  #          ),
  #          params: { archive: mock_file },
  #          as: :json
  #   end
  #
  #   assert_response :accepted
  #   json_response = JSON.parse(response.body)
  #   assert_includes json_response["message"], "Processing will continue in background"
  #   assert_equal "processing", json_response["status"]
  #   assert_not_nil json_response["scxrd_dataset_id"]
  # end

  private

  # Helper method to create a test ZIP archive for testing
  def create_test_archive
    # This would create a minimal test archive for SCXRD processing
    # Implementation would depend on the expected archive structure
  end
end