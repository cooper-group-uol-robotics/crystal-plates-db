class UbMatrixService
  class << self
    # Convert UB matrix to unit cell parameters (a, b, c, alpha, beta, gamma)
    # UB matrix relates reciprocal space to Cartesian coordinates
    # B matrix contains the unit cell parameters
    # U matrix is the crystal orientation matrix
    #
    # The stored UB matrix is dimensionless and must be divided by wavelength
    # to get the real UB matrix in reciprocal space (Å^-1)
    #
    # wavelength: X-ray wavelength in Angstroms (0.71073 for Mo, 1.5418 for Cu)
    def ub_matrix_to_cell_parameters(ub11, ub12, ub13, ub21, ub22, ub23, ub31, ub32, ub33, wavelength = 0.71073)
      # Construct the UB matrix and scale by wavelength to get real UB matrix
      # Stored UB matrix is dimensionless, divide by wavelength to get Å^-1 units
      ub_matrix = [
        [ub11 / wavelength, ub12 / wavelength, ub13 / wavelength],
        [ub21 / wavelength, ub22 / wavelength, ub23 / wavelength],
        [ub31 / wavelength, ub32 / wavelength, ub33 / wavelength]
      ]
      
      # Polar decomposition: UB = U * B where U is orthogonal and B is upper triangular
      # Calculate B^T * B = (UB)^T * (UB)
      btb = matrix_multiply(transpose(ub_matrix), ub_matrix)
      
      # Extract B using Cholesky decomposition
      b_matrix = cholesky_decomposition(btb)
      return nil unless b_matrix
      
      # B matrix structure (upper triangular, reciprocal space):
      # | a*              b*cos(γ*)        c*cos(β*)       |
      # | 0               b*sin(γ*)        -c*sin(β*)cos(α)|
      # | 0               0                 c*sin(β*)sin(α) |
      
      # Extract components directly from B matrix
      a_star = b_matrix[0][0]
      b_star_cos_gamma_star = b_matrix[0][1]
      c_star_cos_beta_star = b_matrix[0][2]
      b_star_sin_gamma_star = b_matrix[1][1]
      minus_c_star_sin_beta_star_cos_alpha = b_matrix[1][2]
      c_star_sin_beta_star_sin_alpha = b_matrix[2][2]
      
      return nil if a_star <= 0
      
      # Calculate b* from its components
      b_star = Math.sqrt(b_star_cos_gamma_star**2 + b_star_sin_gamma_star**2)
      return nil if b_star <= 0
      
      # Calculate c* from its components
      c_star = Math.sqrt(c_star_cos_beta_star**2 + 
                         minus_c_star_sin_beta_star_cos_alpha**2 + 
                         c_star_sin_beta_star_sin_alpha**2)
      return nil if c_star <= 0
      
      # Calculate reciprocal angles using the components
      cos_gamma_star = b_star_cos_gamma_star / b_star
      sin_gamma_star = b_star_sin_gamma_star / b_star
      
      cos_beta_star = c_star_cos_beta_star / c_star
      sin_beta_star = Math.sqrt(minus_c_star_sin_beta_star_cos_alpha**2 + 
                                c_star_sin_beta_star_sin_alpha**2) / c_star
      
      return nil if sin_beta_star.abs < 1e-10
      
      # Calculate cos(α) from B matrix element [1,2]
      cos_alpha = -minus_c_star_sin_beta_star_cos_alpha / (c_star * sin_beta_star)
      cos_alpha = [[-1.0, cos_alpha].max, 1.0].min
      sin_alpha = Math.sqrt(1.0 - cos_alpha**2)
      
      # Calculate cos(α*) using the reciprocal lattice relation
      # For reciprocal lattice: cos(α*) = (cos(β*)cos(γ*) - cos(α))/(sin(β*)sin(γ*))
      # But we need to be careful - let's use the metric tensor relation
      cos_alpha_star = (cos_beta_star * cos_gamma_star - cos_alpha * sin_beta_star * sin_gamma_star)
      cos_alpha_star = [[-1.0, cos_alpha_star].max, 1.0].min
      sin_alpha_star = Math.sqrt(1.0 - cos_alpha_star**2)
      
      # Calculate reciprocal cell volume
      volume_star = a_star * b_star * c_star * 
                    Math.sqrt(1.0 - cos_alpha_star**2 - cos_beta_star**2 - cos_gamma_star**2 + 
                             2.0 * cos_alpha_star * cos_beta_star * cos_gamma_star)
      
      return nil if volume_star.abs < 1e-10
      
      # Convert to direct space
      volume = 1.0 / volume_star
      
      # Direct cell lengths
      a = b_star * c_star * sin_alpha_star / volume_star
      b = a_star * c_star * sin_beta_star / volume_star
      c = a_star * b_star * sin_gamma_star / volume_star
      
      # Direct cell angles using reciprocal lattice relations
      cos_beta = (cos_alpha_star * cos_gamma_star - cos_beta_star) / (sin_alpha_star * sin_gamma_star)
      cos_gamma = (cos_alpha_star * cos_beta_star - cos_gamma_star) / (sin_alpha_star * sin_beta_star)
      
      # Clamp and convert to degrees
      cos_alpha = [[-1.0, cos_alpha].max, 1.0].min
      cos_beta = [[-1.0, cos_beta].max, 1.0].min
      cos_gamma = [[-1.0, cos_gamma].max, 1.0].min
      
      alpha = Math.acos(cos_alpha) * 180.0 / Math::PI
      beta = Math.acos(cos_beta) * 180.0 / Math::PI
      gamma = Math.acos(cos_gamma) * 180.0 / Math::PI
      
      {
        a: a,
        b: b,
        c: c,
        alpha: alpha,
        beta: beta,
        gamma: gamma,
        volume: volume
      }
    rescue => e
      Rails.logger.error "UB Matrix Service: Error converting UB matrix to cell parameters: #{e.message}"
      Rails.logger.error "UB Matrix Service: Backtrace: #{e.backtrace.first(5).join("\n")}"
      nil
    end
    
    private
    
    # Matrix multiplication helper
    def matrix_multiply(a, b)
      rows_a = a.length
      cols_a = a[0].length
      cols_b = b[0].length
      
      result = Array.new(rows_a) { Array.new(cols_b, 0.0) }
      
      (0...rows_a).each do |i|
        (0...cols_b).each do |j|
          (0...cols_a).each do |k|
            result[i][j] += a[i][k] * b[k][j]
          end
        end
      end
      
      result
    end
    
    # Matrix transpose helper
    def transpose(matrix)
      matrix[0].zip(*matrix[1..-1])
    end
    
    # Cholesky decomposition for extracting upper triangular B matrix
    # Input: symmetric positive definite matrix A = B^T * B  
    # Output: upper triangular B such that B^T * B = A
    def cholesky_decomposition(a)
      n = a.length
      l = Array.new(n) { Array.new(n, 0.0) }
      
      # Compute lower triangular L where A = L * L^T
      (0...n).each do |i|
        (0..i).each do |j|
          sum = 0.0
          (0...j).each do |k|
            sum += l[i][k] * l[j][k]
          end
          
          if i == j
            val = a[i][i] - sum
            return nil if val <= 0
            l[i][j] = Math.sqrt(val)
          else
            return nil if l[j][j].abs < 1e-10
            l[i][j] = (a[i][j] - sum) / l[j][j]
          end
        end
      end
      
      # Return transpose to get upper triangular B
      transpose(l)
    rescue => e
      Rails.logger.error "UB Matrix Service: Cholesky decomposition failed: #{e.message}"
      nil
    end
  end
end
