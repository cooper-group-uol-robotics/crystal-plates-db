class ScxrdFolderProcessorService
  require "zip"
  require "tempfile"
  include ActionView::Helpers::NumberHelper

  def initialize(uploaded_folder_path)
    @folder_path = uploaded_folder_path
    @peak_table_data = nil
    @first_image_data = nil
    @zip_data = nil
    @file_count = 0
  end

  def process
    extract_files
    create_zip_archive

    {
      peak_table: @peak_table_data,
      first_image: @first_image_data,
      zip_archive: @zip_data,
      par_data: @par_data
    }
  end

  private

  def extract_files
    return unless Dir.exist?(@folder_path)



    # Find peak table file (*peakhunt.tabbin) - exclude files starting with 'pre_'

    peak_table_pattern = File.join(@folder_path, "**", "*peakhunt.tabbin")
    all_peak_table_files = Dir.glob(peak_table_pattern, File::FNM_CASEFOLD)
    peak_table_files = all_peak_table_files.reject { |file| File.basename(file).start_with?("pre_") }


    if peak_table_files.any?
      peak_table_file = peak_table_files.first

      @peak_table_data = File.binread(peak_table_file) if File.exist?(peak_table_file)

    end

    # Find first diffraction image (frames/*1.rodhypix) - exclude files starting with 'pre_'

    first_image_pattern = File.join(@folder_path, "frames", "*1.rodhypix")
    all_first_image_files = Dir.glob(first_image_pattern, File::FNM_CASEFOLD)
    first_image_files = all_first_image_files.reject { |file| File.basename(file).start_with?("pre_") }


    if first_image_files.any?
      first_image_file = first_image_files.first

      @first_image_data = File.binread(first_image_file) if File.exist?(first_image_file)

    end

    # Find and parse crystal.ini file for reduced cell parameters - exclude files starting with 'pre_'
    Rails.logger.info "SCXRD: Searching for crystal.ini files in folder: #{@folder_path}"
    crystal_ini_pattern = File.join(@folder_path, "expinfo", "*_crystal.ini")
    all_crystal_ini_files = Dir.glob(crystal_ini_pattern, File::FNM_CASEFOLD)
    Rails.logger.info "SCXRD: Found #{all_crystal_ini_files.count} crystal.ini files total: #{all_crystal_ini_files.map { |f| File.basename(f) }.inspect}"

    crystal_ini_files = all_crystal_ini_files.reject { |file| File.basename(file).start_with?("pre_") }
    Rails.logger.info "SCXRD: Found #{crystal_ini_files.count} crystal.ini files (excluding pre_*): #{crystal_ini_files.map { |f| File.basename(f) }.inspect}"

    if crystal_ini_files.any?
      crystal_ini_file = crystal_ini_files.first
      Rails.logger.info "SCXRD: Using crystal.ini file: #{crystal_ini_file}"
      @par_data = parse_crystal_ini_file(crystal_ini_file) if File.exist?(crystal_ini_file)
      Rails.logger.info "SCXRD: crystal.ini parsing result: #{@par_data ? 'SUCCESS' : 'FAILED'}"
      
      # Parse coordinates from cmdscript.mac if parsing succeeded
      if @par_data
        coordinates = parse_cmdscript_coordinates
        @par_data.merge!(coordinates) if coordinates
      end
    else
      Rails.logger.warn "SCXRD: No crystal.ini files found in expinfo folder"
      
      # Fallback to .par file parsing for backwards compatibility
      Rails.logger.info "SCXRD: Falling back to .par file parsing"
      par_pattern = File.join(@folder_path, "**", "*.par")
      all_par_files = Dir.glob(par_pattern, File::FNM_CASEFOLD)
      Rails.logger.info "SCXRD: Found #{all_par_files.count} .par files total: #{all_par_files.map { |f| File.basename(f) }.inspect}"

      par_files = all_par_files.reject { |file| File.basename(file).start_with?("pre_") }
      Rails.logger.info "SCXRD: Found #{par_files.count} .par files (excluding pre_*): #{par_files.map { |f| File.basename(f) }.inspect}"

      if par_files.any?
        par_file = par_files.first
        Rails.logger.info "SCXRD: Using .par file: #{par_file}"
        @par_data = parse_par_file(par_file) if File.exist?(par_file)
        Rails.logger.info "SCXRD: .par parsing result: #{@par_data ? 'SUCCESS' : 'FAILED'}"
        
        # Parse coordinates from cmdscript.mac if parsing succeeded
        if @par_data
          coordinates = parse_cmdscript_coordinates
          @par_data.merge!(coordinates) if coordinates
        end
      else
        Rails.logger.warn "SCXRD: No .par files found either"
      end
    end
  end

  def create_zip_archive
    return unless Dir.exist?(@folder_path)

    # Count total files first
    total_files = count_files_recursively(@folder_path)

    temp_zip = Tempfile.new([ "scxrd_archive", ".zip" ])
    temp_zip.binmode

    begin
      Zip::File.open(temp_zip.path, Zip::File::CREATE) do |zipfile|
        @file_count = 0
        add_directory_to_zip(zipfile, @folder_path, File.basename(@folder_path), total_files)
      end

      temp_zip.rewind
      @zip_data = temp_zip.read


    ensure
      temp_zip.close
      temp_zip.unlink
    end
  end

  def add_directory_to_zip(zipfile, dir_path, zip_dir_name, total_files = nil)
    Dir.foreach(dir_path) do |entry|
      next if entry == "." || entry == ".."

      full_path = File.join(dir_path, entry)
      zip_entry_name = File.join(zip_dir_name, entry)

      if File.directory?(full_path)
        zipfile.mkdir(zip_entry_name) unless zipfile.find_entry(zip_entry_name)
        add_directory_to_zip(zipfile, full_path, zip_entry_name, total_files)
      else
        @file_count += 1
        zipfile.add(zip_entry_name, full_path)

        # Log progress every 500 files to avoid log spam
        if @file_count % 500 == 0
          progress = total_files ? "#{@file_count}/#{total_files}" : @file_count.to_s

        end
      end
    end
  end

  def count_files_recursively(dir_path)
    count = 0
    Dir.glob(File.join(dir_path, "**", "*")).each do |path|
      count += 1 unless File.directory?(path)
    end
    count
  end

  def parse_crystal_ini_file(crystal_ini_file_path)
    Rails.logger.info "SCXRD: Starting to parse crystal.ini file: #{crystal_ini_file_path}"

    begin
      # Check if file exists and is readable
      unless File.exist?(crystal_ini_file_path)
        Rails.logger.error "SCXRD: crystal.ini file does not exist: #{crystal_ini_file_path}"
        return nil
      end

      file_size = File.size(crystal_ini_file_path)
      Rails.logger.info "SCXRD: crystal.ini file size: #{file_size} bytes"

      # Read the file content - crystal.ini files are typically text files
      content = File.read(crystal_ini_file_path, encoding: "UTF-8")
      Rails.logger.info "SCXRD: Successfully read crystal.ini file content (#{content.length} characters)"

      # Look for the reduced cell line
      # Format: reduced cell plus vol=7.2218583  8.5410638 8.5902173 107.6582105 91.8679754 90.9411566 504.4382028
      cell_info = {}
      lines_processed = 0

      content.each_line.with_index do |line, index|
        lines_processed += 1
        # Clean the line
        clean_line = line.strip

        Rails.logger.debug "SCXRD: Processing line #{index + 1}: '#{clean_line}'"

        # Look for the reduced cell line
        if clean_line.start_with?("reduced cell plus vol=")
          Rails.logger.info "SCXRD: Found reduced cell line at line #{index + 1}"
          
          # Extract the numbers after the equals sign
          # Format: reduced cell plus vol=a b c alpha beta gamma volume
          parts = clean_line.split("=")
          if parts.length == 2
            numbers = parts[1].strip.split(/\s+/).map(&:to_f)
            Rails.logger.info "SCXRD: Found #{numbers.length} numbers: #{numbers.inspect}"
            
            if numbers.length >= 6
              # First six numbers are the reduced cell parameters
              cell_info[:a] = numbers[0]
              cell_info[:b] = numbers[1]
              cell_info[:c] = numbers[2]
              cell_info[:alpha] = numbers[3]
              cell_info[:beta] = numbers[4]
              cell_info[:gamma] = numbers[5]
              
              Rails.logger.info "SCXRD: Parsed reduced cell parameters:"
              Rails.logger.info "SCXRD: a=#{cell_info[:a]}, b=#{cell_info[:b]}, c=#{cell_info[:c]}"
              Rails.logger.info "SCXRD: α=#{cell_info[:alpha]}, β=#{cell_info[:beta]}, γ=#{cell_info[:gamma]}"
              
              break # We found what we need
            else
              Rails.logger.warn "SCXRD: Reduced cell line found but insufficient numbers (#{numbers.length})"
            end
          else
            Rails.logger.warn "SCXRD: Reduced cell line found but couldn't parse format"
          end
        end
      end

      Rails.logger.info "SCXRD: Processed #{lines_processed} lines total"
      Rails.logger.info "SCXRD: Final parsed cell_info: #{cell_info.inspect}"

      if cell_info.empty?
        Rails.logger.warn "SCXRD: No reduced cell parameters found in crystal.ini file"
        nil
      else
        Rails.logger.info "SCXRD: Successfully parsed reduced cell parameters from crystal.ini file"
        cell_info
      end

    rescue => e
      Rails.logger.error "SCXRD: Error parsing crystal.ini file #{crystal_ini_file_path}: #{e.message}"
      Rails.logger.error "SCXRD: Backtrace: #{e.backtrace.first(10).join("\n")}"
      nil
    end
  end

  def parse_par_file(par_file_path)
    Rails.logger.info "SCXRD: Starting to parse .par file: #{par_file_path}"

    begin
      # Check if file exists and is readable
      unless File.exist?(par_file_path)
        Rails.logger.error "SCXRD: .par file does not exist: #{par_file_path}"
        return nil
      end

      file_size = File.size(par_file_path)
      Rails.logger.info "SCXRD: .par file size: #{file_size} bytes"

      # Read the file content - .par files are typically text files
      content = File.read(par_file_path, encoding: "ISO-8859-1")
      Rails.logger.info "SCXRD: Successfully read .par file content (#{content.length} characters)"

      # Look for the CELL INFORMATION section
      cell_info = {}
      cell_section_found = false
      lines_processed = 0

      content.each_line.with_index do |line, index|
        lines_processed += 1
        # Clean the line and remove non-ASCII characters
        clean_line = line.encode("UTF-8", "ISO-8859-1", invalid: :replace, undef: :replace).strip

        if clean_line.include?("CELL INFORMATION")
          Rails.logger.info "SCXRD: Found CELL INFORMATION section at line #{index + 1}"
          cell_section_found = true
          next
        end

        # If we found the cell section, look for the unit cell parameters
        if cell_section_found
          Rails.logger.debug "SCXRD: Processing line #{index + 1} in cell section: '#{clean_line}'"

          # Skip empty lines and lines with just asterisks
          if clean_line.empty? || clean_line.match?(/^[*\s]*$/)
            Rails.logger.debug "SCXRD: Skipping empty/asterisk line"
            next
          end

          # Look for lines with numbers (unit cell parameters)
          # Format: a(std) b(std) c(std) on first line
          # alpha(std) beta(std) gamma(std) on second line
          # Allow for special characters at the beginning (like Â§)
          if clean_line.match?(/[\d.]+\s*\(\s*[\d.]+\s*\)/)
            numbers = clean_line.scan(/[\d.]+/)
            Rails.logger.info "SCXRD: Found numeric line with #{numbers.length} numbers: #{numbers.inspect}"

            if cell_info.empty?
              # First line: a, b, c parameters
              cell_info[:a] = numbers[0]&.to_f
              cell_info[:b] = numbers[2]&.to_f  # Skip std dev
              cell_info[:c] = numbers[4]&.to_f  # Skip std dev
              Rails.logger.info "SCXRD: Parsed a, b, c: #{cell_info[:a]}, #{cell_info[:b]}, #{cell_info[:c]}"
            else
              # Second line: alpha, beta, gamma parameters
              cell_info[:alpha] = numbers[0]&.to_f
              cell_info[:beta] = numbers[2]&.to_f  # Skip std dev
              cell_info[:gamma] = numbers[4]&.to_f  # Skip std dev
              Rails.logger.info "SCXRD: Parsed α, β, γ: #{cell_info[:alpha]}, #{cell_info[:beta]}, #{cell_info[:gamma]}"
              break # We have all the parameters we need
            end
          else
            Rails.logger.debug "SCXRD: Line doesn't match numeric pattern: '#{clean_line}'"
          end
        end
      end

      Rails.logger.info "SCXRD: Processed #{lines_processed} lines total"
      Rails.logger.info "SCXRD: Cell section found: #{cell_section_found}"
      Rails.logger.info "SCXRD: Final parsed cell_info: #{cell_info.inspect}"

      if cell_info.empty?
        Rails.logger.warn "SCXRD: No unit cell parameters found in .par file"
        nil
      else
        Rails.logger.info "SCXRD: Successfully parsed unit cell parameters from .par file"
        cell_info
      end

    rescue => e
      Rails.logger.error "SCXRD: Error parsing .par file #{par_file_path}: #{e.message}"
      Rails.logger.error "SCXRD: Backtrace: #{e.backtrace.first(10).join("\n")}"
      nil
    end
  end

  def parse_cmdscript_coordinates
    Rails.logger.info "SCXRD: Searching for cmdscript.mac file"
    
    # Look for cmdscript.mac in the folder
    cmdscript_pattern = File.join(@folder_path, "**", "cmdscript.mac")
    cmdscript_files = Dir.glob(cmdscript_pattern, File::FNM_CASEFOLD)
    
    Rails.logger.info "SCXRD: Found #{cmdscript_files.count} cmdscript.mac files: #{cmdscript_files.map { |f| File.basename(f) }.inspect}"
    
    return nil unless cmdscript_files.any?
    
    cmdscript_file = cmdscript_files.first
    Rails.logger.info "SCXRD: Using cmdscript.mac file: #{cmdscript_file}"
    
    begin
      # Read the first line of the file
      first_line = File.open(cmdscript_file, 'r') { |f| f.readline.strip }
      Rails.logger.info "SCXRD: First line: '#{first_line}'"
      
      # Parse the coordinates from the line format:
      # xx xtalcheck move x 48.25 y 1.33 z 0.08
      if first_line =~ /x\s+([\d.-]+)\s+y\s+([\d.-]+)\s+z\s+([\d.-]+)/
        x_coord = $1.to_f
        y_coord = $2.to_f  
        z_coord = $3.to_f
        
        coordinates = {
          real_world_x_mm: x_coord,
          real_world_y_mm: y_coord,
          real_world_z_mm: z_coord
        }
        
        Rails.logger.info "SCXRD: Parsed coordinates: x=#{x_coord}, y=#{y_coord}, z=#{z_coord}"
        return coordinates
      else
        Rails.logger.warn "SCXRD: Could not parse coordinates from line: '#{first_line}'"
        return nil
      end
      
    rescue => e
      Rails.logger.error "SCXRD: Error parsing cmdscript.mac file #{cmdscript_file}: #{e.message}"
      return nil
    end
  end
end
