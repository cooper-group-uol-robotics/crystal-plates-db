require "test_helper"

class ChemicalTest < ActiveSupport::TestCase
  test "should return empirical formula as molecular formula when available" do
    chemical = chemicals(:one)
    assert_equal "C2H6O", chemical.molecular_formula
  end

  test "should return nil for molecular formula when empirical formula is blank" do
    chemical = Chemical.new(
      sciformation_id: 999,
      name: "Test Chemical",
      smiles: "C",
      empirical_formula: nil
    )
    assert_nil chemical.molecular_formula
  end

  test "should have empirical_formula attribute" do
    chemical = chemicals(:one)
    assert_respond_to chemical, :empirical_formula
    assert_equal "C2H6O", chemical.empirical_formula
  end

  test "should allow setting empirical_formula" do
    chemical = Chemical.new
    chemical.empirical_formula = "H2O"
    assert_equal "H2O", chemical.empirical_formula
  end
end
