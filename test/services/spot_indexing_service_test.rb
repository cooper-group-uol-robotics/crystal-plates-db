# frozen_string_literal: true

require "test_helper"

class SpotIndexingServiceTest < ActiveSupport::TestCase
  test "matrix_inverse calculates correct inverse for simple matrix" do
    # Identity matrix should be its own inverse
    identity = [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0]
    ]
    
    inverse = SpotIndexingService.send(:matrix_inverse, identity)
    assert_not_nil inverse
    
    # Check that inverse is also identity
    assert_in_delta 1.0, inverse[0][0], 0.001
    assert_in_delta 0.0, inverse[0][1], 0.001
    assert_in_delta 0.0, inverse[0][2], 0.001
  end

  test "matrix_inverse returns nil for singular matrix" do
    # All zeros - singular matrix
    singular = [
      [0.0, 0.0, 0.0],
      [0.0, 0.0, 0.0],
      [0.0, 0.0, 0.0]
    ]
    
    inverse = SpotIndexingService.send(:matrix_inverse, singular)
    assert_nil inverse
  end

  test "calculate_indexed_spots counts spots within tolerance" do
    # Simple UB matrix (identity for testing)
    ub_matrix = [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0]
    ]
    
    # Create test spots - some indexed, some not
    data_points = [
      { x: 1.02, y: 2.01, z: 3.03 },  # Close to (1, 2, 3) - indexed
      { x: 1.5, y: 2.5, z: 3.5 },      # Not indexed (far from integers)
      { x: -1.01, y: 0.02, z: 1.98 },  # Close to (-1, 0, 2) - indexed
      { x: 0.01, y: 0.01, z: 0.02 }    # Close to (0, 0, 0) - indexed
    ]
    
    result = SpotIndexingService.calculate_indexed_spots(data_points, ub_matrix, tolerance: 0.125)
    
    assert_equal 4, result[:total_count]
    assert_equal 3, result[:indexed_count]
    assert_in_delta 75.0, result[:indexing_rate], 0.1
    assert_equal 3, result[:indexed_spots].length
  end

  test "calculate_indexed_spots handles empty data points" do
    ub_matrix = [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0]
    ]
    
    result = SpotIndexingService.calculate_indexed_spots([], ub_matrix)
    
    assert_equal 0, result[:total_count]
    assert_equal 0, result[:indexed_count]
    assert_equal [], result[:indexed_spots]
  end

  test "calculate_indexed_spots handles nil UB matrix" do
    data_points = [
      { x: 1.0, y: 2.0, z: 3.0 }
    ]
    
    result = SpotIndexingService.calculate_indexed_spots(data_points, nil)
    
    assert_equal 1, result[:total_count]
    assert_equal 0, result[:indexed_count]
    assert_equal [], result[:indexed_spots]
  end

  test "calculate_indexed_spots works with realistic UB matrix" do
    # A more realistic UB matrix (approximate values from a real dataset)
    ub_matrix = [
      [0.1234, -0.0456, 0.0789],
      [0.0234, 0.1567, -0.0123],
      [-0.0567, 0.0345, 0.1123]
    ]
    
    # Create some test spots - we'll just verify it doesn't crash
    data_points = [
      { x: 1.5, y: 2.3, z: 3.1 },
      { x: 0.9, y: 1.2, z: 2.8 },
      { x: -1.1, y: 0.5, z: 1.9 }
    ]
    
    result = SpotIndexingService.calculate_indexed_spots(data_points, ub_matrix, tolerance: 0.125)
    
    assert_equal 3, result[:total_count]
    assert result[:indexed_count].is_a?(Integer)
    assert result[:indexed_count] >= 0
    assert result[:indexed_count] <= 3
  end

  test "determinant_3x3 calculates correct determinant" do
    matrix = [
      [1.0, 2.0, 3.0],
      [4.0, 5.0, 6.0],
      [7.0, 8.0, 9.0]
    ]
    
    # This matrix has determinant 0 (rows are linearly dependent)
    det = SpotIndexingService.send(:determinant_3x3, matrix)
    assert_in_delta 0.0, det, 0.001
  end

  test "matrix_vector_multiply works correctly" do
    matrix = [
      [1.0, 0.0, 0.0],
      [0.0, 2.0, 0.0],
      [0.0, 0.0, 3.0]
    ]
    vector = [1.0, 2.0, 3.0]
    
    result = SpotIndexingService.send(:matrix_vector_multiply, matrix, vector)
    
    assert_in_delta 1.0, result[0], 0.001
    assert_in_delta 4.0, result[1], 0.001
    assert_in_delta 9.0, result[2], 0.001
  end

  test "calculate_indexed_spots respects custom tolerance" do
    ub_matrix = [
      [1.0, 0.0, 0.0],
      [0.0, 1.0, 0.0],
      [0.0, 0.0, 1.0]
    ]
    
    # Spot with distances slightly above default tolerance
    data_points = [
      { x: 1.15, y: 2.15, z: 3.15 }  # 0.15 from integers
    ]
    
    # Should not be indexed with default tolerance (0.125)
    result_strict = SpotIndexingService.calculate_indexed_spots(data_points, ub_matrix, tolerance: 0.125)
    assert_equal 0, result_strict[:indexed_count]
    
    # Should be indexed with relaxed tolerance
    result_relaxed = SpotIndexingService.calculate_indexed_spots(data_points, ub_matrix, tolerance: 0.20)
    assert_equal 1, result_relaxed[:indexed_count]
  end
end
