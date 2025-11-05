require 'test_helper'

class FormulaParserServiceTest < ActiveSupport::TestCase
  test "parses simple molecular formulas" do
    assert_equal({ "C" => 2, "H" => 6, "O" => 1 }, FormulaParserService.parse("C2H6O"))
    assert_equal({ "H" => 2, "O" => 1 }, FormulaParserService.parse("H2O"))
    assert_equal({ "Na" => 1, "Cl" => 1 }, FormulaParserService.parse("NaCl"))
  end

  test "parses formulas with spaces" do
    assert_equal({ "C" => 2, "H" => 6, "O" => 1 }, FormulaParserService.parse("C2 H6 O"))
    assert_equal({ "Ca" => 1, "C" => 1, "O" => 3 }, FormulaParserService.parse("Ca CO3"))
  end

  test "parses formulas with parentheses" do
    assert_equal({ "Ca" => 1, "N" => 2, "O" => 6 }, FormulaParserService.parse("Ca(NO3)2"))
    assert_equal({ "Al" => 2, "S" => 3, "O" => 12 }, FormulaParserService.parse("Al2(SO4)3"))
  end

  test "parses hydrates and dot notation" do
    assert_equal({ "Ca" => 1, "Cl" => 2, "H" => 4, "O" => 2 }, FormulaParserService.parse("CaCl2·2H2O"))
    assert_equal({ "Cu" => 1, "S" => 1, "O" => 4, "H" => 10 }, FormulaParserService.parse("CuSO4•5H2O"))
    assert_equal({ "Na" => 2, "S" => 1, "O" => 3, "H" => 14 }, FormulaParserService.parse("Na2SO3*7H2O"))
  end

  test "handles single atoms without numbers" do
    assert_equal({ "C" => 1 }, FormulaParserService.parse("C"))
    assert_equal({ "Fe" => 1 }, FormulaParserService.parse("Fe"))
  end

  test "handles empty and invalid input gracefully" do
    assert_equal({}, FormulaParserService.parse(""))
    assert_equal({}, FormulaParserService.parse(nil))
    assert_equal({}, FormulaParserService.parse("  "))
  end

  test "parse_safely handles errors gracefully" do
    # This should not raise an error even with malformed input
    result = FormulaParserService.parse_safely("C2H6O((invalid")
    assert_instance_of Hash, result
  end

  test "valid_formula? correctly identifies valid formulas" do
    assert FormulaParserService.valid_formula?("C2H6O")
    assert FormulaParserService.valid_formula?("H2O")
    assert_not FormulaParserService.valid_formula?("")
    assert_not FormulaParserService.valid_formula?(nil)
    assert_not FormulaParserService.valid_formula?("   ")
  end

  test "parses complex nested parentheses" do
    # This is a complex case: Mg3(PO4)2
    assert_equal({ "Mg" => 3, "P" => 2, "O" => 8 }, FormulaParserService.parse("Mg3(PO4)2"))
  end

  test "parses real chemical examples" do
    # Test with fixture examples
    assert_equal({ "C" => 2, "H" => 6, "O" => 1 }, FormulaParserService.parse("C2H6O")) # ethanol
    assert_equal({ "C" => 2, "H" => 4, "O" => 2 }, FormulaParserService.parse("C2H4O2")) # acetic acid
  end
end