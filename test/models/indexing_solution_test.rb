require "test_helper"

class IndexingSolutionTest < ActiveSupport::TestCase
  def setup
    @solution = indexing_solutions(:one)
    @dataset = scxrd_datasets(:one)
  end

  test "belongs to scxrd_dataset" do
    assert_instance_of ScxrdDataset, @solution.scxrd_dataset
  end

  test "has_ub_matrix? returns true when all components present" do
    assert @solution.has_ub_matrix?
  end

  test "has_ub_matrix? returns false when components missing" do
    @solution.ub11 = nil
    assert_not @solution.has_ub_matrix?
  end

  test "has_primitive_cell? returns true when all parameters present" do
    assert @solution.has_primitive_cell?
  end

  test "has_primitive_cell? returns false when parameters missing" do
    @solution.primitive_a = nil
    assert_not @solution.has_primitive_cell?
  end

  test "ub_matrix_as_array returns 3x3 matrix" do
    matrix = @solution.ub_matrix_as_array
    assert_equal 3, matrix.length
    assert_equal 3, matrix[0].length
    assert_equal @solution.ub11, matrix[0][0]
    assert_equal @solution.ub33, matrix[2][2]
  end

  test "indexing_rate calculates percentage correctly" do
    @solution.spots_found = 1000
    @solution.spots_indexed = 750
    assert_equal 75.0, @solution.indexing_rate
  end

  test "indexing_rate returns nil when spots_found is nil" do
    @solution.spots_found = nil
    assert_nil @solution.indexing_rate
  end

  test "indexing_rate returns nil when spots_found is zero" do
    @solution.spots_found = 0
    assert_nil @solution.indexing_rate
  end

  test "display_label includes source and indexing rate" do
    @solution.source = "CIF"
    @solution.spots_found = 1000
    @solution.spots_indexed = 785
    
    label = @solution.display_label
    assert_includes label, "CIF"
    assert_includes label, "78.5%"
  end

  test "ordered_by_quality scope orders by spots_indexed desc" do
    solutions = @dataset.indexing_solutions.ordered_by_quality
    # Solution :one has 785 indexed, :two has 723 indexed
    assert_equal indexing_solutions(:one), solutions.first
    assert_equal indexing_solutions(:two), solutions.second
  end

  test "validates numericality of unit cell parameters" do
    @solution.primitive_a = -1
    assert_not @solution.valid?
    assert_includes @solution.errors[:primitive_a], "must be greater than 0"
  end

  test "validates numericality of spots counts" do
    @solution.spots_found = -5
    assert_not @solution.valid?
    assert_includes @solution.errors[:spots_found], "must be greater than or equal to 0"
  end
end
