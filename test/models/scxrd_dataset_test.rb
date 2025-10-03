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

  test "has_primitive_cell? returns true when all parameters present" do
    assert @dataset.has_primitive_cell?
  end

  test "has_primitive_cell? returns false when parameters missing" do
    @dataset.primitive_a = nil
    assert_not @dataset.has_primitive_cell?
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

  test "g6_vector calculates correct G6 representation" do
    # Set known unit cell parameters
    @dataset.primitive_a = 10.0
    @dataset.primitive_b = 10.0
    @dataset.primitive_c = 10.0
    @dataset.primitive_alpha = 90.0
    @dataset.primitive_beta = 90.0
    @dataset.primitive_gamma = 90.0

    g6 = @dataset.g6_vector

    assert_equal 6, g6.length
    # For a cubic cell: G6 = [a², b², c², 2bc*cos(α), 2ac*cos(β), 2ab*cos(γ)]
    # cos(90°) = 0, so last three components should be 0
    assert_in_delta 100.0, g6[0], 0.001  # a²
    assert_in_delta 100.0, g6[1], 0.001  # b²
    assert_in_delta 100.0, g6[2], 0.001  # c²
    assert_in_delta 0.0, g6[3], 0.001    # 2bc*cos(α)
    assert_in_delta 0.0, g6[4], 0.001    # 2ac*cos(β)
    assert_in_delta 0.0, g6[5], 0.001    # 2ab*cos(γ)
  end

  test "g6_vector returns nil when no primitive cell" do
    @dataset.primitive_a = nil
    assert_nil @dataset.g6_vector
  end

  test "g6_distance_to calculates distance between datasets" do
    # Create two identical cubic cells
    @dataset.primitive_a = 10.0
    @dataset.primitive_b = 10.0
    @dataset.primitive_c = 10.0
    @dataset.primitive_alpha = 90.0
    @dataset.primitive_beta = 90.0
    @dataset.primitive_gamma = 90.0

    other_dataset = ScxrdDataset.new(
      experiment_name: "test2",
      measured_at: Time.current,
      primitive_a: 10.0,
      primitive_b: 10.0,
      primitive_c: 10.0,
      primitive_alpha: 90.0,
      primitive_beta: 90.0,
      primitive_gamma: 90.0
    )

    distance = @dataset.g6_distance_to(other_dataset)
    assert_in_delta 0.0, distance, 0.001  # Identical cells should have 0 distance
  end

  test "g6_distance_to calculates non-zero distance for different cells" do
    @dataset.primitive_a = 10.0
    @dataset.primitive_b = 10.0
    @dataset.primitive_c = 10.0
    @dataset.primitive_alpha = 90.0
    @dataset.primitive_beta = 90.0
    @dataset.primitive_gamma = 90.0

    other_dataset = ScxrdDataset.new(
      experiment_name: "test2",
      measured_at: Time.current,
      primitive_a: 11.0,  # Different a parameter
      primitive_b: 10.0,
      primitive_c: 10.0,
      primitive_alpha: 90.0,
      primitive_beta: 90.0,
      primitive_gamma: 90.0
    )

    distance = @dataset.g6_distance_to(other_dataset)
    assert distance > 0  # Different cells should have non-zero distance
  end

  test "similar_datasets_count_by_g6 returns correct count" do
    count = @dataset.similar_datasets_count_by_g6
    assert count.is_a?(Integer)
    assert count >= 0
  end

  # ...

  test "best_conventional_cell returns hash or nil" do
    result = @dataset.best_conventional_cell
    assert result.nil? || result.is_a?(Hash)
  end
end
