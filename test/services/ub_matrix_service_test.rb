require "test_helper"

class UbMatrixServiceTest < ActiveSupport::TestCase
  test "converts UB matrix to cell parameters correctly" do
    # Example UB matrix from a known cubic crystal (simplified for testing)
    # This represents a unit cell with a=b=c=10Å and alpha=beta=gamma=90°
    # UB matrix for cubic system (approximate values in Å^-1)
    ub11 = 0.1
    ub12 = 0.0
    ub13 = 0.0
    ub21 = 0.0
    ub22 = 0.1
    ub23 = 0.0
    ub31 = 0.0
    ub32 = 0.0
    ub33 = 0.1
    wavelength = 1.0  # Use 1.0 for no scaling (values already in Å^-1)

    result = UbMatrixService.ub_matrix_to_cell_parameters(
      ub11, ub12, ub13,
      ub21, ub22, ub23,
      ub31, ub32, ub33,
      wavelength
    )

    assert_not_nil result
    assert_in_delta 10.0, result[:a], 0.1, "Cell parameter a should be ~10Å"
    assert_in_delta 10.0, result[:b], 0.1, "Cell parameter b should be ~10Å"
    assert_in_delta 10.0, result[:c], 0.1, "Cell parameter c should be ~10Å"
    assert_in_delta 90.0, result[:alpha], 1.0, "Cell angle alpha should be ~90°"
    assert_in_delta 90.0, result[:beta], 1.0, "Cell angle beta should be ~90°"
    assert_in_delta 90.0, result[:gamma], 1.0, "Cell angle gamma should be ~90°"
  end

  test "converts realistic UB matrix values" do
    # Using realistic values from the user's example (in Å^-1)
    ub11 = 5.41663077870E-02
    ub12 = 1.19307712811E-02
    ub13 = 2.23492806450E-02
    ub21 = 2.03678053387E-02
    ub22 = -2.15667381406E-02
    ub23 = 1.58944187845E-02
    ub31 = 6.71691977991E-02
    ub32 = -2.83506788777E-03
    ub33 = -2.28588798291E-02
    wavelength = 1.0  # Use 1.0 for no scaling (values already in Å^-1)

    result = UbMatrixService.ub_matrix_to_cell_parameters(
      ub11, ub12, ub13,
      ub21, ub22, ub23,
      ub31, ub32, ub33,
      wavelength
    )

    assert_not_nil result, "Should successfully convert UB matrix"
    assert result[:a] > 0, "Cell parameter a should be positive"
    assert result[:b] > 0, "Cell parameter b should be positive"
    assert result[:c] > 0, "Cell parameter c should be positive"
    assert result[:alpha] > 0, "Cell angle alpha should be positive"
    assert result[:alpha] < 180, "Cell angle alpha should be less than 180°"
    assert result[:beta] > 0, "Cell angle beta should be positive"
    assert result[:beta] < 180, "Cell angle beta should be less than 180°"
    assert result[:gamma] > 0, "Cell angle gamma should be positive"
    assert result[:gamma] < 180, "Cell angle gamma should be less than 180°"
    assert result[:volume] > 0, "Cell volume should be positive"
  end

  test "handles zero matrix gracefully" do
    result = UbMatrixService.ub_matrix_to_cell_parameters(
      0, 0, 0,
      0, 0, 0,
      0, 0, 0,
      0.71073  # Mo wavelength
    )

    # Should return nil or handle error gracefully
    assert_nil result
  end
end
