require "test_helper"

class StockSolutionValidationTest < ActiveSupport::TestCase
  def setup
    @chemical = chemicals(:one)
    @stock_solution = StockSolution.new(name: "Test Solution")
  end

  test "should validate components with invalid amount_with_unit" do
    @stock_solution.stock_solution_components.build(
      chemical: @chemical,
      amount_with_unit: "invalid format"
    )

    assert_not @stock_solution.valid?

    # The component should have errors
    component = @stock_solution.stock_solution_components.first
    assert_not component.valid?
    assert_includes component.errors[:amount_with_unit], "must be in format like '10 mg', '5.5 ml', etc."
  end

  test "should validate components with valid amount_with_unit" do
    @stock_solution.stock_solution_components.build(
      chemical: @chemical,
      amount_with_unit: "10 mg"
    )

    assert @stock_solution.valid?

    # The component should be valid
    component = @stock_solution.stock_solution_components.first
    assert component.valid?
    assert_equal 10.0, component.amount
    assert_equal "mg", component.unit.symbol
  end
end
