# frozen_string_literal: true

# Spot Indexing Service
# Calculates how many spots from a peak table are indexed by a UB matrix
# A spot is considered indexed if its hkl indices are close to integers

class SpotIndexingService
  # Default tolerance for considering a spot indexed (distance from integer)
  DEFAULT_TOLERANCE = 0.125

  class << self
    # Calculate the number of indexed spots given peak table data and UB matrix
    # 
    # @param data_points [Array<Hash>] Array of peak positions with :x, :y, :z keys
    # @param ub_matrix [Array<Array<Float>>] 3x3 UB matrix
    # @param tolerance [Float] Maximum distance from integer for h, k, l to be considered indexed
    # @return [Hash] { indexed_count: Integer, total_count: Integer, indexed_spots: Array }
    def calculate_indexed_spots(data_points, ub_matrix, tolerance: DEFAULT_TOLERANCE)
      return { indexed_count: 0, total_count: 0, indexed_spots: [] } if data_points.nil? || data_points.empty?
      return { indexed_count: 0, total_count: data_points.length, indexed_spots: [] } if ub_matrix.nil?

      # Calculate inverse of UB matrix
      ub_inverse = matrix_inverse(ub_matrix)
      return { indexed_count: 0, total_count: data_points.length, indexed_spots: [] } if ub_inverse.nil?

      indexed_spots = []
      
      data_points.each_with_index do |point, idx|
        xyz = [point[:x], point[:y], point[:z]]
        hkl = matrix_vector_multiply(ub_inverse, xyz)
        
        if spot_is_indexed?(hkl, tolerance)
          h_distance = (hkl[0] - hkl[0].round).abs
          k_distance = (hkl[1] - hkl[1].round).abs
          l_distance = (hkl[2] - hkl[2].round).abs
          
          indexed_spots << {
            index: idx,
            xyz: xyz,
            hkl: hkl,
            hkl_rounded: [hkl[0].round, hkl[1].round, hkl[2].round],
            distances: {
              h: h_distance,
              k: k_distance,
              l: l_distance
            }
          }
        end
      end

      {
        indexed_count: indexed_spots.length,
        total_count: data_points.length,
        indexed_spots: indexed_spots,
        indexing_rate: data_points.length > 0 ? (indexed_spots.length.to_f / data_points.length * 100).round(2) : 0.0
      }
    rescue => e
      Rails.logger.error "SpotIndexingService: Error calculating indexed spots: #{e.message}"
      Rails.logger.error "SpotIndexingService: Backtrace: #{e.backtrace.first(5).join("\n")}"
      { indexed_count: 0, total_count: data_points&.length || 0, indexed_spots: [] }
    end

    # Enrich data points in-place with indexing information
    # Adds an :indexed boolean to each data point
    # 
    # @param data_points [Array<Hash>] Array of peak positions with :x, :y, :z keys (modified in place)
    # @param ub_matrix [Array<Array<Float>>] 3x3 UB matrix
    # @param tolerance [Float] Maximum distance from integer for h, k, l to be considered indexed
    # @return [Boolean] true if successful, false otherwise
    def enrich_with_indexing_info!(data_points, ub_matrix, tolerance: DEFAULT_TOLERANCE)
      return false if data_points.nil? || data_points.empty? || ub_matrix.nil?

      # Calculate inverse of UB matrix
      ub_inverse = matrix_inverse(ub_matrix)
      return false if ub_inverse.nil?

      # Check each data point and mark as indexed or not
      data_points.each do |point|
        xyz = [point[:x], point[:y], point[:z]]
        hkl = matrix_vector_multiply(ub_inverse, xyz)
        point[:indexed] = spot_is_indexed?(hkl, tolerance)
      end

      true
    rescue => e
      Rails.logger.error "SpotIndexingService: Error enriching with indexing info: #{e.message}"
      Rails.logger.error "SpotIndexingService: Backtrace: #{e.backtrace.first(5).join("\n")}"
      false
    end

    private

    # Check if a spot is indexed based on hkl indices
    # @param hkl [Array<Float>] Array of h, k, l indices
    # @param tolerance [Float] Maximum distance from integer
    # @return [Boolean] true if all indices are within tolerance of integers
    def spot_is_indexed?(hkl, tolerance)
      h_distance = (hkl[0] - hkl[0].round).abs
      k_distance = (hkl[1] - hkl[1].round).abs
      l_distance = (hkl[2] - hkl[2].round).abs
      
      h_distance <= tolerance && k_distance <= tolerance && l_distance <= tolerance
    end

    # Calculate the inverse of a 3x3 matrix
    # @param matrix [Array<Array<Float>>] 3x3 matrix
    # @return [Array<Array<Float>>] Inverse matrix or nil if singular
    def matrix_inverse(matrix)
      return nil unless matrix.is_a?(Array) && matrix.length == 3
      return nil unless matrix.all? { |row| row.is_a?(Array) && row.length == 3 }

      # Calculate determinant
      det = determinant_3x3(matrix)
      return nil if det.abs < 1e-10  # Matrix is singular

      # Calculate cofactor matrix
      cofactor = [
        [
          cofactor_2x2(matrix, 0, 0),
          -cofactor_2x2(matrix, 0, 1),
          cofactor_2x2(matrix, 0, 2)
        ],
        [
          -cofactor_2x2(matrix, 1, 0),
          cofactor_2x2(matrix, 1, 1),
          -cofactor_2x2(matrix, 1, 2)
        ],
        [
          cofactor_2x2(matrix, 2, 0),
          -cofactor_2x2(matrix, 2, 1),
          cofactor_2x2(matrix, 2, 2)
        ]
      ]

      # Transpose cofactor matrix and divide by determinant
      inverse = Array.new(3) { Array.new(3) }
      (0..2).each do |i|
        (0..2).each do |j|
          inverse[i][j] = cofactor[j][i] / det
        end
      end

      inverse
    end

    # Calculate determinant of a 3x3 matrix
    def determinant_3x3(matrix)
      a, b, c = matrix[0]
      d, e, f = matrix[1]
      g, h, i = matrix[2]

      a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    end

    # Calculate cofactor for element at (row, col)
    def cofactor_2x2(matrix, row, col)
      # Extract the 2x2 minor matrix
      minor_rows = (0..2).to_a - [row]
      minor_cols = (0..2).to_a - [col]

      a = matrix[minor_rows[0]][minor_cols[0]]
      b = matrix[minor_rows[0]][minor_cols[1]]
      c = matrix[minor_rows[1]][minor_cols[0]]
      d = matrix[minor_rows[1]][minor_cols[1]]

      a * d - b * c
    end

    # Multiply a 3x3 matrix by a 3x1 vector
    def matrix_vector_multiply(matrix, vector)
      result = Array.new(3, 0.0)
      (0..2).each do |i|
        (0..2).each do |j|
          result[i] += matrix[i][j] * vector[j]
        end
      end
      result
    end
  end
end
