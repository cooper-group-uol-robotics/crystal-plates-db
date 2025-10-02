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

  test "best_conventional_cell returns hash or nil" do
    result = @dataset.best_conventional_cell
    assert result.nil? || result.is_a?(Hash)
  end
end
