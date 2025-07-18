require "test_helper"

class StockSolutionAmountParsingTest < ActionDispatch::IntegrationTest
  setup do
    @chemical = chemicals(:one)
    @mg_unit = Unit.find_by(symbol: "mg") || Unit.create!(name: "milligram", symbol: "mg", conversion_to_base: 1.0)
  end

  test "should create stock solution with amount_with_unit" do
    assert_difference("StockSolution.count") do
      post stock_solutions_path, params: {
        stock_solution: {
          name: "Test Solution",
          stock_solution_components_attributes: {
            "0" => {
              chemical_id: @chemical.id,
              amount_with_unit: "10 mg"
            }
          }
        }
      }
    end

    stock_solution = StockSolution.last
    component = stock_solution.stock_solution_components.first

    assert_equal 10.0, component.amount
    assert_equal "mg", component.unit.symbol
    assert_equal @chemical, component.chemical
  end

  test "should handle different units" do
    assert_difference("StockSolution.count") do
      post stock_solutions_path, params: {
        stock_solution: {
          name: "Multi-Unit Solution",
          stock_solution_components_attributes: {
            "0" => {
              chemical_id: @chemical.id,
              amount_with_unit: "5.5 ml"
            }
          }
        }
      }
    end

    component = StockSolution.last.stock_solution_components.first
    assert_equal 5.5, component.amount
    assert_equal "ml", component.unit.symbol
  end

  test "should reject invalid amount format" do
    # Simply check that the stock solution is not created when invalid
    initial_count = StockSolution.count

    post stock_solutions_path, params: {
      stock_solution: {
        name: "Invalid Solution",
        stock_solution_components_attributes: {
          "0" => {
            chemical_id: @chemical.id,
            amount_with_unit: "invalid format"
          }
        }
      }
    }

    # The key test: no stock solution should be created
    assert_equal initial_count, StockSolution.count
    assert_not StockSolution.exists?(name: "Invalid Solution")
  end
end
