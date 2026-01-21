require "test_helper"

class ScxrdDatasetTest < ActiveSupport::TestCase
  def setup
    @well = wells(:one)
    @dataset = ScxrdDataset.create!(
      well: @well,
      experiment_name: "test_experiment",
      measured_at: Time.current,
      primitive_a: 10.24,
      primitive_b: 13.87,
      primitive_c: 7.14,
      primitive_alpha: 90.0,
      primitive_beta: 91.98,
      primitive_gamma: 90.0
    )

    # Mock configuration
    Rails.application.config.lepage_api_enabled = true
  end

  test "has_ub_matrix? returns true when all UB matrix components present" do
    @dataset.ub11 = 0.1
    @dataset.ub12 = 0.0
    @dataset.ub13 = 0.0
    @dataset.ub21 = 0.0
    @dataset.ub22 = 0.1
    @dataset.ub23 = 0.0
    @dataset.ub31 = 0.0
    @dataset.ub32 = 0.0
    @dataset.ub33 = 0.1
    
    assert @dataset.has_ub_matrix?
  end

  test "has_ub_matrix? returns false when components missing" do
    @dataset.ub11 = 0.1
    @dataset.ub22 = 0.1
    # Missing other components
    assert_not @dataset.has_ub_matrix?
  end

  test "ub_matrix_as_array returns matrix" do
    @dataset.ub11 = 0.1
    @dataset.ub12 = 0.0
    @dataset.ub13 = 0.0
    @dataset.ub21 = 0.0
    @dataset.ub22 = 0.1
    @dataset.ub23 = 0.0
    @dataset.ub31 = 0.0
    @dataset.ub32 = 0.0
    @dataset.ub33 = 0.1
    
    matrix = @dataset.ub_matrix_as_array
    assert_equal 3, matrix.length
    assert_equal 3, matrix[0].length
    assert_equal 0.1, matrix[0][0]
  end

  test "cell_parameters_from_ub_matrix returns parameters" do
    @dataset.ub11 = 0.1
    @dataset.ub12 = 0.0
    @dataset.ub13 = 0.0
    @dataset.ub21 = 0.0
    @dataset.ub22 = 0.1
    @dataset.ub23 = 0.0
    @dataset.ub31 = 0.0
    @dataset.ub32 = 0.0
    @dataset.ub33 = 0.1
    
    params = @dataset.cell_parameters_from_ub_matrix
    assert_not_nil params
    assert params[:a] > 0
    assert params[:b] > 0
    assert params[:c] > 0
  end

  test "has_primitive_cell? returns true when all parameters present" do
    assert @dataset.has_primitive_cell?
  end

  test "has_primitive_cell? returns false when parameters missing" do
    @dataset.primitive_a = nil
    assert_not @dataset.has_primitive_cell?
  end

  test "has_conventional_cell? returns true when all parameters present" do
    @dataset.conventional_a = 10.0
    @dataset.conventional_b = 11.0
    @dataset.conventional_c = 12.0
    @dataset.conventional_alpha = 90.0
    @dataset.conventional_beta = 90.0
    @dataset.conventional_gamma = 90.0
    
    assert @dataset.has_conventional_cell?
  end

  test "has_conventional_cell? returns false when parameters missing" do
    @dataset.conventional_a = 10.0
    # Missing other parameters
    assert_not @dataset.has_conventional_cell?
  end

  test "display_cell returns fallback primitive cell when API unavailable" do
    # This will test the fallback when the API call fails
    result = @dataset.display_cell
    # Should return primitive cell as fallback if API fails
    assert result[:bravais].present?
    assert result[:a].present?
  end

  test "display_cell returns nil when no primitive cell" do
    @dataset.primitive_a = nil

    assert_nil @dataset.display_cell
  end

  test "conventional_cells returns array" do
    result = @dataset.conventional_cells
    assert result.is_a?(Array)
  end

  test "extract_cell_params_for_g6 returns correct parameters" do
    # Set known unit cell parameters
    @dataset.primitive_a = 10.0
    @dataset.primitive_b = 10.0
    @dataset.primitive_c = 10.0
    @dataset.primitive_alpha = 90.0
    @dataset.primitive_beta = 90.0
    @dataset.primitive_gamma = 90.0

    cell_params = @dataset.extract_cell_params_for_g6

    assert_equal 10.0, cell_params[:a]
    assert_equal 10.0, cell_params[:b]
    assert_equal 10.0, cell_params[:c]
    assert_equal 90.0, cell_params[:alpha]
    assert_equal 90.0, cell_params[:beta]
    assert_equal 90.0, cell_params[:gamma]
  end

  test "g6_distance_to returns nil when no primitive cell" do
    # Dataset without primitive cell parameters
    other_dataset = ScxrdDataset.new(
      experiment_name: "test2",
      measured_at: Time.current
    )

    distance = @dataset.g6_distance_to(other_dataset)
    assert_nil distance
  end

  test "g6_distance_to returns nil when other dataset has no primitive cell" do
    @dataset.primitive_a = 10.0
    @dataset.primitive_b = 10.0
    @dataset.primitive_c = 10.0
    @dataset.primitive_alpha = 90.0
    @dataset.primitive_beta = 90.0
    @dataset.primitive_gamma = 90.0

    other_dataset = ScxrdDataset.new(
      experiment_name: "test2",
      measured_at: Time.current
      # No primitive cell parameters
    )

    distance = @dataset.g6_distance_to(other_dataset)
    assert_nil distance
  end

  test "similar_datasets_by_g6 returns empty when no primitive cell" do
    # Dataset without primitive cell parameters
    similar_datasets = @dataset.similar_datasets_by_g6(tolerance: 10.0)
    assert_equal [], similar_datasets
  end

  # ...

  test "best_conventional_cell returns hash or nil" do
    result = @dataset.best_conventional_cell
    assert result.nil? || result.is_a?(Hash)
  end

  test "associated_chemical_formulas returns empty array when no well" do
    @dataset.well = nil
    @dataset.save!
    
    formulas = @dataset.associated_chemical_formulas
    assert_equal [], formulas
  end

  test "associated_chemical_formulas includes direct chemical formulas" do
    # Add a chemical directly to the well
    chemical = chemicals(:one)  # This should have empirical_formula "C2H6O"
    WellContent.create!(
      well: @well,
      contentable: chemical,
      volume: 50.0,
      unit: units(:microliters)
    )

    formulas = @dataset.associated_chemical_formulas
    assert_includes formulas, chemical.empirical_formula
  end

  test "associated_chemical_formulas includes stock solution component formulas" do
    # Create a stock solution with chemicals
    stock_solution = StockSolution.create!(name: "Test Stock Solution")
    chemical = chemicals(:two)  # This should have empirical_formula "C2H4O2"
    
    # Create unit if it doesn't exist
    unit = Unit.find_by(symbol: 'mM') || Unit.create!(
      name: 'millimolar', 
      symbol: 'mM',
      conversion_to_base: 1.0
    )
    
    # Add chemical to stock solution
    StockSolutionComponent.create!(
      stock_solution: stock_solution,
      chemical: chemical,
      amount: 10.0,
      unit: unit
    )
    
    # Add stock solution to well
    WellContent.create!(
      well: @well,
      contentable: stock_solution,
      volume: 100.0,
      unit: units(:microliters)
    )

    formulas = @dataset.associated_chemical_formulas
    assert_includes formulas, chemical.empirical_formula
  end

  test "formula_matches_well_contents? returns false for empty CSD formula" do
    assert_not @dataset.formula_matches_well_contents?("")
    assert_not @dataset.formula_matches_well_contents?(nil)
  end

  test "formula_matches_well_contents? returns false when no well chemicals" do
    # Well with no content
    assert_not @dataset.formula_matches_well_contents?("C2H6O")
  end

  test "formula_matches_well_contents? returns true for matching formula" do
    # Add a chemical to the well
    chemical = chemicals(:one)  # "C2H6O"
    WellContent.create!(
      well: @well,
      contentable: chemical,
      volume: 50.0,
      unit: units(:microliters)
    )

    # Should match exact formula
    assert @dataset.formula_matches_well_contents?("C2H6O")
    
    # Should match within tolerance (±1 atom)
    assert @dataset.formula_matches_well_contents?("C2H7O")  # +1 H
    assert @dataset.formula_matches_well_contents?("C2H5O")  # -1 H
    
    # Should not match outside tolerance
    assert_not @dataset.formula_matches_well_contents?("C2H10O")  # +4 H
  end

  test "best_matching_formula returns nil when no matches" do
    result = @dataset.best_matching_formula("C10H20O10")
    assert_nil result
  end

  test "best_matching_formula returns matching formula" do
    # Add a chemical to the well
    chemical = chemicals(:one)  # "C2H6O"
    WellContent.create!(
      well: @well,
      contentable: chemical,
      volume: 50.0,
      unit: units(:microliters)
    )

    # Should return the exact match
    result = @dataset.best_matching_formula("C2H6O")
    assert_equal "C2H6O", result
    
    # Should return the best match within tolerance
    result = @dataset.best_matching_formula("C2H7O")  # Close to C2H6O
    assert_equal "C2H6O", result
  end
end
