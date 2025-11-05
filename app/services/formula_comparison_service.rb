class FormulaComparisonService
  # Compare two chemical formulas with tolerance
  # Returns true if formulas are similar within tolerance
  # Tolerance: each element count may differ by +/- 1 or 10% (whichever is greater)
  def self.formulas_match?(formula1, formula2, tolerance_percent: 10.0)
    return false if formula1.blank? || formula2.blank?
    
    # Parse both formulas
    elements1 = FormulaParserService.parse_safely(formula1)
    elements2 = FormulaParserService.parse_safely(formula2)
    
    return false if elements1.empty? || elements2.empty?
    
    compare_parsed_formulas(elements1, elements2, tolerance_percent: tolerance_percent)
  end
  
  # Compare two parsed formula hashes
  def self.compare_parsed_formulas(elements1, elements2, tolerance_percent: 10.0)
    # Get all unique elements from both formulas
    all_elements = (elements1.keys + elements2.keys).uniq
    
    # Check each element
    all_elements.each do |element|
      count1 = elements1[element] || 0
      count2 = elements2[element] || 0
      
      unless counts_within_tolerance?(count1, count2, tolerance_percent: tolerance_percent)
        return false
      end
    end
    
    true
  end
  
  # Check if two counts are within tolerance
  # Tolerance: +/- 1 atom or tolerance_percent%, whichever is greater
  def self.counts_within_tolerance?(count1, count2, tolerance_percent: 10.0)
    # Calculate absolute difference
    diff = (count1 - count2).abs
    
    # Calculate tolerance for the larger count
    max_count = [count1, count2].max
    return true if max_count == 0 # Both are zero
    
    # Calculate percentage tolerance (minimum 1 atom)
    percent_tolerance = [(max_count * tolerance_percent / 100.0).ceil, 1].max
    
    # Return true if difference is within tolerance
    diff <= percent_tolerance
  end
  
  # Get formula similarity score (0.0 to 1.0)
  # Higher score means more similar formulas
  def self.formula_similarity_score(formula1, formula2)
    return 0.0 if formula1.blank? || formula2.blank?
    
    elements1 = FormulaParserService.parse_safely(formula1)
    elements2 = FormulaParserService.parse_safely(formula2)
    
    return 0.0 if elements1.empty? || elements2.empty?
    
    calculate_similarity_score(elements1, elements2)
  end
  
  # Compare a formula against multiple formulas
  # Returns array of matching formulas with their similarity scores
  def self.find_matching_formulas(target_formula, candidate_formulas, tolerance_percent: 10.0)
    return [] if target_formula.blank? || candidate_formulas.empty?
    
    target_elements = FormulaParserService.parse_safely(target_formula)
    return [] if target_elements.empty?
    
    matches = []
    
    candidate_formulas.each do |candidate|
      next if candidate.blank?
      
      candidate_elements = FormulaParserService.parse_safely(candidate)
      next if candidate_elements.empty?
      
      if compare_parsed_formulas(target_elements, candidate_elements, tolerance_percent: tolerance_percent)
        similarity = calculate_similarity_score(target_elements, candidate_elements)
        matches << {
          formula: candidate,
          similarity_score: similarity,
          is_exact_match: similarity == 1.0
        }
      end
    end
    
    # Sort by similarity score (highest first)
    matches.sort_by { |m| -m[:similarity_score] }
  end
  
  private
  
  def self.calculate_similarity_score(elements1, elements2)
    all_elements = (elements1.keys + elements2.keys).uniq
    return 1.0 if all_elements.empty?
    
    total_similarity = 0.0
    total_weight = 0.0
    
    all_elements.each do |element|
      count1 = elements1[element] || 0
      count2 = elements2[element] || 0
      
      # Weight by the maximum count (more important elements have higher impact)
      weight = [count1, count2].max
      next if weight == 0
      
      # Calculate element similarity (1.0 for exact match, decreasing with difference)
      max_count = [count1, count2].max
      diff = (count1 - count2).abs
      element_similarity = 1.0 - (diff.to_f / [max_count, 1].max)
      element_similarity = [element_similarity, 0.0].max # Ensure non-negative
      
      total_similarity += element_similarity * weight
      total_weight += weight
    end
    
    return 1.0 if total_weight == 0
    total_similarity / total_weight
  end
end