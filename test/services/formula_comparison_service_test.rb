require 'test_helper'

class FormulaComparisonServiceTest < ActiveSupport::TestCase
  test "exact formula matches return true" do
    assert FormulaComparisonService.formulas_match?("C2H6O", "C2H6O")
    assert FormulaComparisonService.formulas_match?("H2O", "H2O")
  end

  test "formulas within tolerance match" do
    # Different by 1 atom - should match (tolerance allows +/- 1 or 10%)
    assert FormulaComparisonService.formulas_match?("C2H6O", "C2H7O") # +1 H
    assert FormulaComparisonService.formulas_match?("C2H6O", "C2H5O") # -1 H
    assert FormulaComparisonService.formulas_match?("C2H6O", "C3H6O") # +1 C
  end

  test "formulas outside tolerance do not match" do
    # Different by more than tolerance - should not match
    assert_not FormulaComparisonService.formulas_match?("C2H6O", "C2H10O") # +4 H (too much)
    assert_not FormulaComparisonService.formulas_match?("C2H6O", "C5H6O") # +3 C (too much)
    assert_not FormulaComparisonService.formulas_match?("C2H6O", "C2H6O5") # +4 O (too much)
  end

  test "percentage tolerance works for larger numbers" do
    # For larger counts, 10% tolerance should be used
    # C20H40O10 vs C20H44O10 (difference of 4 H, which is 10% of 40)
    assert FormulaComparisonService.formulas_match?("C20H40O10", "C20H44O10", tolerance_percent: 10.0)
    # But difference of 8 H (20% of 40) should not match
    assert_not FormulaComparisonService.formulas_match?("C20H40O10", "C20H48O10", tolerance_percent: 10.0)
  end

  test "empty or blank formulas do not match" do
    assert_not FormulaComparisonService.formulas_match?("", "C2H6O")
    assert_not FormulaComparisonService.formulas_match?("C2H6O", "")
    assert_not FormulaComparisonService.formulas_match?(nil, "C2H6O")
    assert_not FormulaComparisonService.formulas_match?("C2H6O", nil)
  end

  test "counts_within_tolerance works correctly" do
    # Test the core tolerance logic
    assert FormulaComparisonService.counts_within_tolerance?(5, 5) # exact match
    assert FormulaComparisonService.counts_within_tolerance?(5, 6) # +1
    assert FormulaComparisonService.counts_within_tolerance?(5, 4) # -1
    assert_not FormulaComparisonService.counts_within_tolerance?(5, 8) # +3 (too much)
    
    # Test percentage tolerance
    assert FormulaComparisonService.counts_within_tolerance?(20, 22, tolerance_percent: 10.0) # +2 (10% of 20 = 2)
    assert_not FormulaComparisonService.counts_within_tolerance?(20, 25, tolerance_percent: 10.0) # +5 (25% of 20)
  end

  test "formula_similarity_score returns sensible values" do
    # Exact match should return 1.0
    assert_equal 1.0, FormulaComparisonService.formula_similarity_score("C2H6O", "C2H6O")
    
    # Partial match should return value between 0 and 1
    similarity = FormulaComparisonService.formula_similarity_score("C2H6O", "C2H7O")
    assert similarity > 0.5 && similarity < 1.0
    
    # Completely different formulas should return low score
    similarity = FormulaComparisonService.formula_similarity_score("C2H6O", "CaCl2")
    assert similarity < 0.5
    
    # Empty formula should return 0
    assert_equal 0.0, FormulaComparisonService.formula_similarity_score("", "C2H6O")
  end

  test "find_matching_formulas returns correct matches" do
    candidates = ["C2H6O", "C2H7O", "C2H10O", "H2O", "CaCl2"]
    matches = FormulaComparisonService.find_matching_formulas("C2H6O", candidates)
    
    # Should find C2H6O (exact) and C2H7O (within tolerance)
    assert_equal 2, matches.length
    assert matches.any? { |m| m[:formula] == "C2H6O" && m[:is_exact_match] }
    assert matches.any? { |m| m[:formula] == "C2H7O" && !m[:is_exact_match] }
    
    # Should be sorted by similarity (exact match first)
    assert_equal "C2H6O", matches.first[:formula]
  end

  test "works with real chemical examples from fixtures" do
    # Using examples from our test fixtures
    ethanol = "C2H6O"
    acetic_acid = "C2H4O2"
    
    # Different chemicals should not match
    assert_not FormulaComparisonService.formulas_match?(ethanol, acetic_acid)
    
    # But slight variations should match
    assert FormulaComparisonService.formulas_match?(ethanol, "C2H7O") # +1 H
    assert FormulaComparisonService.formulas_match?(acetic_acid, "C2H5O2") # +1 H
  end
end