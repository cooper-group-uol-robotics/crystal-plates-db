require "test_helper"

class ScxrdDatasetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @plate = plates(:one)
    @well = wells(:one)  # Assuming well fixture exists
    @scxrd_dataset = scxrd_datasets(:one)  # Assuming scxrd_dataset fixture exists
  end

  test "user provided coordinates take precedence over parsed coordinates" do
    # Create a mock ZIP file with cmdscript.mac containing coordinates
    zip_data = create_test_zip_with_coordinates(
      cmdscript_coords: { x: 10.5, y: 20.3, z: 30.7 },
      crystal_ini_data: "reduced cell plus vol=7.2218583  8.5410638 8.5902173 107.6582105 91.8679754 90.9411566 504.4382028"
    )
    
    # Mock the ScxrdFolderProcessorService to return our test data
    mock_service = Minitest::Mock.new
    mock_service.expect :process, {
      par_data: {
        a: 7.2218583, b: 8.5410638, c: 8.5902173,
        alpha: 107.6582105, beta: 91.8679754, gamma: 90.9411566,
        real_world_x_mm: 10.5, real_world_y_mm: 20.3, real_world_z_mm: 30.7
      },
      zip_archive: zip_data,
      peak_table: nil,
      first_image: nil
    }
    
    ScxrdFolderProcessorService.stub :new, mock_service do
      # Post with user-provided coordinates that should override parsed ones
      post well_scxrd_datasets_path(@well), params: {
        scxrd_dataset: {
          experiment_name: "test_experiment",
          real_world_x_mm: 100.1,  # User provided - should override parsed 10.5
          real_world_y_mm: 200.2,  # User provided - should override parsed 20.3
          real_world_z_mm: "",     # Empty - should use parsed 30.7
          compressed_archive: fixture_file_upload('files/test.zip', 'application/zip')
        }
      }
      
      # Verify the dataset was created with correct coordinates
      dataset = ScxrdDataset.last
      assert_equal 100.1, dataset.real_world_x_mm  # User value used
      assert_equal 200.2, dataset.real_world_y_mm  # User value used  
      assert_equal 30.7, dataset.real_world_z_mm   # Parsed value used (user provided empty)
      
      # Verify unit cell parameters from parsing were stored
      assert_equal 7.2218583, dataset.niggli_a
      assert_equal 8.5410638, dataset.niggli_b
    end
    
    mock_service.verify
  end

  test "parsed coordinates used when user provides none" do
    # Create mock service that returns parsed coordinates
    mock_service = Minitest::Mock.new
    mock_service.expect :process, {
      par_data: {
        a: 7.2218583, b: 8.5410638, c: 8.5902173,
        alpha: 107.6582105, beta: 91.8679754, gamma: 90.9411566,
        real_world_x_mm: 15.5, real_world_y_mm: 25.3, real_world_z_mm: 35.7
      },
      zip_archive: "mock zip data",
      peak_table: nil,
      first_image: nil
    }
    
    ScxrdFolderProcessorService.stub :new, mock_service do
      # Post without user-provided coordinates
      post well_scxrd_datasets_path(@well), params: {
        scxrd_dataset: {
          experiment_name: "test_experiment2",
          compressed_archive: fixture_file_upload('files/test.zip', 'application/zip')
        }
      }
      
      # Verify the dataset was created with parsed coordinates
      dataset = ScxrdDataset.last
      assert_equal 15.5, dataset.real_world_x_mm  # Parsed value used
      assert_equal 25.3, dataset.real_world_y_mm  # Parsed value used
      assert_equal 35.7, dataset.real_world_z_mm  # Parsed value used
    end
    
    mock_service.verify
  end

  private

  def create_test_zip_with_coordinates(cmdscript_coords:, crystal_ini_data:)
    # This would create a mock ZIP file for testing
    # For simplicity, just return a string that represents ZIP data
    "mock zip data with coordinates"
  end
end