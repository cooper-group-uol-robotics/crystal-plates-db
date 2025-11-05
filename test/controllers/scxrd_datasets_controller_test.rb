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

  test "csd_search should respond with formula categorization" do
    # Setup: Add a chemical to the well for formula testing
    chemical = chemicals(:one)  # "C2H6O"
    WellContent.create!(
      well: @well,
      contentable: chemical,
      volume: 50.0,
      unit: units(:microliters)
    )
    
    # Mock a successful CSD search response
    mock_response_data = [
      {
        'identifier' => 'TESTCSD001',
        'formula' => 'C2H6O',  # Should match well contents
        'space_group' => 'P1',
        'cell_parameters' => [10.0, 13.0, 7.0, 90.0, 92.0, 90.0]
      },
      {
        'identifier' => 'TESTCSD002', 
        'formula' => 'C10H20O10',  # Should not match well contents
        'space_group' => 'P21',
        'cell_parameters' => [10.1, 13.1, 7.1, 90.1, 91.9, 90.1]
      }
    ]
    
    # Test the categorization logic directly using the controller's private method
    controller = ScxrdDatasetsController.new
    controller.instance_variable_set(:@scxrd_dataset, @scxrd_dataset)
    
    # Test the categorization method directly
    categorized = controller.send(:categorize_csd_results_by_formula_match, mock_response_data)
    
    # Verify categorization worked correctly
    assert_equal 2, categorized[:all_results].length
    assert_equal 1, categorized[:cell_and_formula_matches].length
    assert_equal 1, categorized[:cell_only_matches].length
    
    # Verify match types were assigned
    complete_match = categorized[:cell_and_formula_matches].first
    assert_equal 'cell_and_formula', complete_match['match_type']
    assert_equal 'C2H6O', complete_match['matched_well_formula']
    
    cell_only_match = categorized[:cell_only_matches].first  
    assert_equal 'cell_only', cell_only_match['match_type']
  end

  test "csd_search returns error when dataset has no primitive cell" do
    # Create dataset without unit cell parameters
    dataset_no_cell = ScxrdDataset.create!(
      well: @well,
      experiment_name: "test_no_cell",
      measured_at: Time.current
      # No primitive cell parameters
    )
    
    post "/scxrd_datasets/#{dataset_no_cell.id}/csd_search", 
         params: { max_hits: 50 },
         as: :json

    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_not json_response['success']
    assert_includes json_response['error'], 'unit cell parameters'
  end
end
