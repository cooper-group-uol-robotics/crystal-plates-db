require "test_helper"

class StockSolutionComponentTest < ActiveSupport::TestCase
  def setup
    @component = stock_solution_components(:one)
  end

  test "should be valid" do
    assert @component.valid?
  end

  test "should require amount" do
    @component.amount = nil
    assert_not @component.valid?
    assert_includes @component.errors[:amount], "can't be blank"
  end

  test "should require positive amount" do
    @component.amount = -1
    assert_not @component.valid?
    assert_includes @component.errors[:amount], "must be greater than 0"
  end

  test "should require stock_solution" do
    @component.stock_solution = nil
    assert_not @component.valid?
    assert_includes @component.errors[:stock_solution], "must exist"
  end

  test "should require chemical" do
    @component.chemical = nil
    assert_not @component.valid?
    assert_includes @component.errors[:chemical], "must exist"
  end

  test "should require unit" do
    @component.unit = nil
    assert_not @component.valid?
    assert_includes @component.errors[:unit], "must exist"
  end

  test "should not allow duplicate chemical in same stock solution" do
    duplicate_component = StockSolutionComponent.new(
      stock_solution: @component.stock_solution,
      chemical: @component.chemical,
      amount: 5.0,
      unit: @component.unit
    )
    assert_not duplicate_component.valid?
    assert_includes duplicate_component.errors[:chemical_id], "can only be added once per stock solution"
  end

  test "display_amount should format amount with unit symbol" do
    expected = "#{@component.amount} #{@component.unit.symbol}"
    assert_equal expected, @component.display_amount
  end

  test "formatted_component should include chemical name and amount" do
    expected = "#{@component.chemical.name}: #{@component.display_amount}"
    assert_equal expected, @component.formatted_component
  end
end
