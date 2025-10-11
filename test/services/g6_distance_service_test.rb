require "test_helper"

class G6DistanceServiceTest < ActiveSupport::TestCase
  def setup
    # Create test settings for the API
    Setting.set("conventional_cell_api_endpoint", "http://localhost:3001")
    Setting.set("conventional_cell_api_timeout", "5")
  end

  test "enabled? returns true when API endpoint is configured" do
    assert G6DistanceService.enabled?
  end

  test "enabled? returns false when API endpoint is not configured" do
    Setting.set("conventional_cell_api_endpoint", "")
    refute G6DistanceService.enabled?
  end

  test "format_cell_for_api converts hash to array format" do
    cell_params = {
      a: 10.0,
      b: 11.0,
      c: 12.0,
      alpha: 90.0,
      beta: 95.0,
      gamma: 100.0
    }

    formatted = G6DistanceService.send(:format_cell_for_api, cell_params)
    expected = [ 10.0, 11.0, 12.0, 90.0, 95.0, 100.0 ]

    assert_equal expected, formatted
  end

  test "valid_unit_cell? validates cell parameters" do
    valid_cell = {
      a: 10.0,
      b: 11.0,
      c: 12.0,
      alpha: 90.0,
      beta: 95.0,
      gamma: 100.0
    }

    invalid_cell = {
      a: nil,
      b: 11.0,
      c: 12.0,
      alpha: 90.0,
      beta: 95.0,
      gamma: 100.0
    }

    assert G6DistanceService.send(:valid_unit_cell?, valid_cell)
    refute G6DistanceService.send(:valid_unit_cell?, invalid_cell)
  end

  test "calculate_distances returns nil when API is disabled" do
    Setting.set("conventional_cell_api_endpoint", "")

    reference_cell = {
      a: 10.0, b: 10.0, c: 10.0,
      alpha: 90.0, beta: 90.0, gamma: 90.0
    }

    comparison_cells = [
      { a: 11.0, b: 10.0, c: 10.0, alpha: 90.0, beta: 90.0, gamma: 90.0 }
    ]

    distances = G6DistanceService.calculate_distances(reference_cell, comparison_cells)
    assert_nil distances
  end

  test "calculate_distances returns nil for invalid reference cell" do
    reference_cell = {
      a: nil, b: 10.0, c: 10.0,
      alpha: 90.0, beta: 90.0, gamma: 90.0
    }

    comparison_cells = [
      { a: 11.0, b: 10.0, c: 10.0, alpha: 90.0, beta: 90.0, gamma: 90.0 }
    ]

    distances = G6DistanceService.calculate_distances(reference_cell, comparison_cells)
    assert_nil distances
  end

  test "calculate_distances returns nil for empty comparison cells" do
    reference_cell = {
      a: 10.0, b: 10.0, c: 10.0,
      alpha: 90.0, beta: 90.0, gamma: 90.0
    }

    distances = G6DistanceService.calculate_distances(reference_cell, [])
    assert_nil distances
  end

  test "find_similar_datasets returns empty array when reference dataset has no primitive cell" do
    reference_dataset = ScxrdDataset.new # No primitive cell parameters
    candidates = [ ScxrdDataset.new ]

    similar = G6DistanceService.find_similar_datasets(reference_dataset, candidates, tolerance: 10.0)
    assert_equal [], similar
  end

  test "find_similar_datasets returns empty array when no candidates" do
    reference_dataset = ScxrdDataset.new(
      primitive_a: 10.0, primitive_b: 10.0, primitive_c: 10.0,
      primitive_alpha: 90.0, primitive_beta: 90.0, primitive_gamma: 90.0
    )

    similar = G6DistanceService.find_similar_datasets(reference_dataset, [], tolerance: 10.0)
    assert_equal [], similar
  end

  test "api_available? returns false when API is disabled" do
    Setting.set("conventional_cell_api_endpoint", "")
    refute G6DistanceService.api_available?
  end
end
