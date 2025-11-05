class FormulaParserService
  # Parse a chemical formula string into a hash of element => count
  # Supports formats like:
  # - "C2H6O" => {"C" => 2, "H" => 6, "O" => 1}
  # - "C2 H6 O" => {"C" => 2, "H" => 6, "O" => 1}
  # - "CaCl2·2H2O" => {"Ca" => 1, "Cl" => 2, "H" => 4, "O" => 2}
  # - "Ca(NO3)2" => {"Ca" => 1, "N" => 2, "O" => 6}
  def self.parse(formula_string)
    return {} if formula_string.blank?

    # Clean the formula string
    formula = formula_string.strip
    
    # Handle hydrates and special characters (·, •, *)
    formula = formula.gsub(/[·•*]/, ' ')
    
    # Initialize element count hash
    elements = {}
    
    # Split by spaces and process each part
    parts = formula.split(/\s+/)
    
    parts.each do |part|
      part_elements = parse_formula_part(part)
      merge_element_counts!(elements, part_elements)
    end
    
    elements
  end
  
  # Parse formulas with error handling
  def self.parse_safely(formula_string)
    begin
      parse(formula_string)
    rescue StandardError => e
      Rails.logger.warn "Failed to parse formula '#{formula_string}': #{e.message}"
      {}
    end
  end
  
  # Check if a formula string appears valid (contains at least one element)
  def self.valid_formula?(formula_string)
    return false if formula_string.blank?
    parsed = parse_safely(formula_string)
    parsed.any?
  end
  
  private
  
  def self.parse_formula_part(part)
    elements = {}
    
    # Regular expression to match element symbols and counts
    # Matches: Ca, Ca2, NO3, (NO3)2, etc.
    regex = /([A-Z][a-z]?)(\d*)|\(([^)]+)\)(\d+)/
    
    # Handle parentheses first
    part = expand_parentheses(part)
    
    # Now parse the expanded formula
    part.scan(/([A-Z][a-z]?)(\d*)/) do |element, count|
      count = count.empty? ? 1 : count.to_i
      elements[element] = (elements[element] || 0) + count
    end
    
    elements
  end
  
  def self.expand_parentheses(formula)
    # Handle nested parentheses by expanding them
    # Add safety counter to prevent infinite loops
    max_iterations = 20
    iteration_count = 0
    
    while formula.include?('(') && iteration_count < max_iterations
      iteration_count += 1
      
      new_formula = formula.gsub(/\(([^()]+)\)(\d+)/) do |match|
        inner_formula = $1
        multiplier = $2.to_i
        
        # Validate multiplier is reasonable
        if multiplier > 1000
          Rails.logger.warn "Large multiplier detected in formula: #{multiplier}"
          multiplier = [multiplier, 1000].min
        end
        
        # Parse the inner formula and multiply counts
        inner_elements = {}
        inner_formula.scan(/([A-Z][a-z]?)(\d*)/) do |element, count|
          count = count.empty? ? 1 : count.to_i
          inner_elements[element] = (inner_elements[element] || 0) + count
        end
        
        # Convert back to formula string with multiplied counts
        expanded = inner_elements.map { |element, count| 
          total_count = count * multiplier
          total_count == 1 ? element : "#{element}#{total_count}"
        }.join('')
        
        expanded
      end
      
      # Break if no change (prevents infinite loop)
      break if new_formula == formula
      formula = new_formula
    end
    
    if iteration_count >= max_iterations
      Rails.logger.warn "Formula parsing hit iteration limit: #{formula}"
    end
    
    formula
  end
  
  def self.merge_element_counts!(target_hash, source_hash)
    source_hash.each do |element, count|
      target_hash[element] = (target_hash[element] || 0) + count
    end
  end
end