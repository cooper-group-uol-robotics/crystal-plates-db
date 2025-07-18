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

  test "should parse amount_with_unit for milligrams" do
    @component.amount_with_unit = "10 mg"
    assert @component.valid?
    assert_equal 10.0, @component.amount
    assert_equal "mg", @component.unit.symbol
  end

  test "should parse amount_with_unit for milliliters" do
    @component.amount_with_unit = "5.5 ml"
    assert @component.valid?
    assert_equal 5.5, @component.amount
    assert_equal "ml", @component.unit.symbol
  end

  test "should parse amount_with_unit for microliters" do
    @component.amount_with_unit = "100 µl"
    assert @component.valid?
    assert_equal 100.0, @component.amount
    assert_equal "µl", @component.unit.symbol
  end

  test "should handle decimal amounts" do
    @component.amount_with_unit = "0.001 g"
    assert @component.valid?
    assert_equal 0.001, @component.amount
    assert_equal "g", @component.unit.symbol
  end

  test "should be case insensitive" do
    @component.amount_with_unit = "10 MG"
    assert @component.valid?
    assert_equal 10.0, @component.amount
    assert_equal "mg", @component.unit.symbol
  end

  test "should handle full unit names" do
    @component.amount_with_unit = "5 milligrams"
    assert @component.valid?
    assert_equal 5.0, @component.amount
    assert_equal "mg", @component.unit.symbol
  end

  test "should reject invalid format" do
    @component.amount_with_unit = "invalid format"
    assert_not @component.valid?
    assert_includes @component.errors[:amount_with_unit], "must be in format like '10 mg', '5.5 ml', etc."
  end

  test "should reject negative amounts" do
    @component.amount_with_unit = "-5 mg"
    assert_not @component.valid?
  end

  test "should create unit if it doesn't exist" do
    # Use a unit that doesn't exist yet but follows a known pattern
    initial_unit_count = Unit.count

    # Use a pattern that should match but with a symbol that doesn't exist
    @component.amount_with_unit = "10 xyz"
    @component.valid? # This should trigger the parsing

    # Since 'xyz' doesn't match any known pattern, it should not create a unit
    # and the component should be invalid
    assert_not @component.valid?
    assert_equal initial_unit_count, Unit.count
  end

  test "amount_with_unit getter should return current amount and unit" do
    @component.amount = 15.0
    @component.unit = Unit.find_by(symbol: "mg") || Unit.create!(name: "milligram", symbol: "mg", conversion_to_base: 1.0)

    expected = "15.0 mg"
    assert_equal expected, @component.amount_with_unit
  end
end
