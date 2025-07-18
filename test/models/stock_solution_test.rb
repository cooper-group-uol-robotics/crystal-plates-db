require "test_helper"

class StockSolutionTest < ActiveSupport::TestCase
  def setup
    @stock_solution = stock_solutions(:one)
  end

  test "should be valid" do
    assert @stock_solution.valid?
  end

  test "should require name" do
    @stock_solution.name = nil
    assert_not @stock_solution.valid?
    assert_includes @stock_solution.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    duplicate_solution = StockSolution.new(name: @stock_solution.name)
    assert_not duplicate_solution.valid?
    assert_includes duplicate_solution.errors[:name], "has already been taken"
  end

  test "display_name should return name if present" do
    assert_equal @stock_solution.name, @stock_solution.display_name
  end

  test "display_name should return fallback if name is blank" do
    @stock_solution.name = ""
    expected = "Stock Solution ##{@stock_solution.id}"
    assert_equal expected, @stock_solution.display_name
  end

  test "total_components should return count of components" do
    assert_equal @stock_solution.stock_solution_components.count, @stock_solution.total_components
  end

  test "can_be_deleted should return true if no well contents" do
    # Create a stock solution with no well contents
    empty_solution = StockSolution.create!(name: "Empty Solution")
    assert_equal 0, empty_solution.well_contents.count
    assert empty_solution.can_be_deleted?
  end

  test "can_be_deleted should return false if has well contents" do
    # The fixture stock solution has well contents
    assert @stock_solution.well_contents.count > 0
    assert_not @stock_solution.can_be_deleted?
  end

  test "should destroy associated components when destroyed" do
    component_count = @stock_solution.stock_solution_components.count
    assert_difference("StockSolutionComponent.count", -component_count) do
      @stock_solution.destroy
    end
  end
end
