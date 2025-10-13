class ScxrdFolderProcessorService
  require "zip"
  require "tempfile"
  include ActionView::Helpers::NumberHelper

  def initialize(uploaded_folder_path)
    @folder_path = uploaded_folder_path
    @peak_table_data = nil
    @all_diffraction_images = []
    @zip_data = nil
    @file_count = 0
    @crystal_image_data = nil
    @structure_file_data = nil
  end

  def process
    extract_files
    create_zip_archive

    {
      peak_table: @peak_table_data,
      all_diffraction_images: @all_diffraction_images,
      zip_archive: @zip_data,
      metadata: @metadata,
      crystal_image: @crystal_image_data,
      structure_file: @structure_file_data
    }
  end

  private

  def extract_files
    return unless Dir.exist?(@folder_path)

    # Extract all diffraction images first
    extract_all_diffraction_images

    # Find peak table file (*peakhunt.tabbin) - exclude files starting with 'pre_'
    peak_table_pattern = File.join(@folder_path, "**", "*peakhunt.tabbin")
    all_peak_table_files = Dir.glob(peak_table_pattern, File::FNM_CASEFOLD)
    peak_table_files = all_peak_table_files.reject { |file| File.basename(file).start_with?("pre_") }

    if peak_table_files.any?
      peak_table_file = peak_table_files.first
      Rails.logger.info "SCXRD: Found peak table file: #{peak_table_file}"

      if File.exist?(peak_table_file)
        @peak_table_data = File.binread(peak_table_file)
        Rails.logger.info "SCXRD: Peak table data extracted successfully (#{@peak_table_data.bytesize} bytes)"
      else
        Rails.logger.warn "SCXRD: Peak table file does not exist: #{peak_table_file}"
      end
    else
      Rails.logger.info "SCXRD: No peak table files found"
    end

    # Find and parse crystal.ini file for reduced cell parameters - exclude files starting with 'pre_'
    Rails.logger.info "SCXRD: Searching for crystal.ini files in folder: #{@folder_path}"
    crystal_ini_pattern = File.join(@folder_path, "expinfo", "*_crystal.ini")
    all_crystal_ini_files = Dir.glob(crystal_ini_pattern, File::FNM_CASEFOLD)
    Rails.logger.info "SCXRD: Found #{all_crystal_ini_files.count} crystal.ini files total: #{all_crystal_ini_files.map { |f| File.basename(f) }.inspect}"

    crystal_ini_files = all_crystal_ini_files.reject { |file| File.basename(file).start_with?("pre_") }
    Rails.logger.info "SCXRD: Found #{crystal_ini_files.count} crystal.ini files (excluding pre_*): #{crystal_ini_files.map { |f| File.basename(f) }.inspect}"

    if crystal_ini_files.any?
      # Prefer files starting with 'wit_' over other files
      wit_crystal_ini_files = crystal_ini_files.select { |file| File.basename(file).start_with?("wit_") }
      crystal_ini_file = wit_crystal_ini_files.any? ? wit_crystal_ini_files.first : crystal_ini_files.first

      if wit_crystal_ini_files.any?
        Rails.logger.info "SCXRD: Preferring wit_ crystal.ini file: #{crystal_ini_file}"
      else
        Rails.logger.info "SCXRD: Using crystal.ini file: #{crystal_ini_file}"
      end

      @metadata = parse_crystal_ini_file(crystal_ini_file) if File.exist?(crystal_ini_file)
      Rails.logger.info "SCXRD: crystal.ini parsing result: #{@metadata ? 'SUCCESS' : 'FAILED'}"
    else
      Rails.logger.warn "SCXRD: No crystal.ini files found in expinfo folder"
    end

    # Find and parse datacoll.ini file for measurement start time - exclude files starting with 'pre_'
    Rails.logger.info "SCXRD: Searching for datacoll.ini files in folder: #{@folder_path}"
    datacoll_ini_pattern = File.join(@folder_path, "expinfo", "*_datacoll.ini")
    all_datacoll_ini_files = Dir.glob(datacoll_ini_pattern, File::FNM_CASEFOLD)
    Rails.logger.info "SCXRD: Found #{all_datacoll_ini_files.count} datacoll.ini files total: #{all_datacoll_ini_files.map { |f| File.basename(f) }.inspect}"

    datacoll_ini_files = all_datacoll_ini_files.reject { |file| File.basename(file).start_with?("pre_") }
    Rails.logger.info "SCXRD: Found #{datacoll_ini_files.count} datacoll.ini files (excluding pre_*): #{datacoll_ini_files.map { |f| File.basename(f) }.inspect}"

    if datacoll_ini_files.any?
      # Prefer files starting with 'wit_' over other files
      wit_datacoll_ini_files = datacoll_ini_files.select { |file| File.basename(file).start_with?("wit_") }
      datacoll_ini_file = wit_datacoll_ini_files.any? ? wit_datacoll_ini_files.first : datacoll_ini_files.first

      if wit_datacoll_ini_files.any?
        Rails.logger.info "SCXRD: Preferring wit_ datacoll.ini file: #{datacoll_ini_file}"
      else
        Rails.logger.info "SCXRD: Using datacoll.ini file: #{datacoll_ini_file}"
      end

      measurement_time = parse_datacoll_ini_file(datacoll_ini_file) if File.exist?(datacoll_ini_file)
      Rails.logger.info "SCXRD: datacoll.ini parsing result: #{measurement_time ? 'SUCCESS' : 'FAILED'}"

      # Initialize @metadata if it doesn't exist and add measurement time
      @metadata ||= {}
      @metadata.merge!(measurement_time) if measurement_time
    else
      Rails.logger.warn "SCXRD: No datacoll.ini files found in expinfo folder"
    end

    # Parse coordinates from cmdscript.mac if parsing succeeded
    if @metadata
      coordinates = parse_cmdscript_coordinates
      @metadata.merge!(coordinates) if coordinates
    end

    # Extract crystal image from movie/oneclickmovie*.jpg
    extract_crystal_image

    # Extract structure file from struct/best_res/*.res
    extract_structure_file
  end

  def extract_all_diffraction_images
    Rails.logger.info "SCXRD: Starting to extract all diffraction images from frames folder"

    frames_pattern = File.join(@folder_path, "frames", "*.rodhypix")
    all_rodhypix_files = Dir.glob(frames_pattern, File::FNM_CASEFOLD)

    # Exclude files starting with 'pre_'
    rodhypix_files = all_rodhypix_files.reject { |file| File.basename(file).start_with?("pre_") }

    Rails.logger.info "SCXRD: Found #{rodhypix_files.length} diffraction images (excluding pre_* files)"

    @all_diffraction_images = []

    rodhypix_files.each do |file_path|
      filename = File.basename(file_path)

      # Parse filename to extract run number and image number
      # Expected format: <variable_string>_<run_number>_<image_number>.rodhypix
      if filename =~ /^(.+)_(\d+)_(\d+)\.rodhypix$/i
        base_name = $1
        run_number = $2.to_i
        image_number = $3.to_i

        begin
          image_data = File.binread(file_path)
          file_size = image_data.bytesize

          @all_diffraction_images << {
            filename: filename,
            run_number: run_number,
            image_number: image_number,
            data: image_data,
            file_size: file_size
          }

          Rails.logger.debug "SCXRD: Extracted #{filename} - Run: #{run_number}, Image: #{image_number}, Size: #{number_to_human_size(file_size)}"
        rescue => e
          Rails.logger.error "SCXRD: Error reading diffraction image #{filename}: #{e.message}"
        end
      else
        Rails.logger.warn "SCXRD: Filename #{filename} doesn't match expected pattern <name>_<run>_<image>.rodhypix"
      end
    end

    # Sort by run number and image number for consistent ordering
    @all_diffraction_images.sort_by! { |img| [ img[:run_number], img[:image_number] ] }

    Rails.logger.info "SCXRD: Successfully extracted #{@all_diffraction_images.length} diffraction images"

    if @all_diffraction_images.any?
      runs = @all_diffraction_images.group_by { |img| img[:run_number] }.keys.sort
      Rails.logger.info "SCXRD: Found runs: #{runs.join(', ')}"

      runs.each do |run|
        images_in_run = @all_diffraction_images.select { |img| img[:run_number] == run }
        image_numbers = images_in_run.map { |img| img[:image_number] }.sort
        Rails.logger.info "SCXRD: Run #{run}: #{images_in_run.length} images (#{image_numbers.first}-#{image_numbers.last})"
      end

      total_size = @all_diffraction_images.sum { |img| img[:file_size] }
      Rails.logger.info "SCXRD: Total diffraction images size: #{number_to_human_size(total_size)}"
    end
  end

  def create_zip_archive
    return unless Dir.exist?(@folder_path)

    # Count total files first
    total_files = count_files_recursively(@folder_path)

    temp_zip = Tempfile.new([ "scxrd_archive", ".zip" ])
    temp_zip.binmode

    begin
      Zip::File.open(temp_zip.path, create: true) do |zipfile|
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

      # Look for the reduced cell line first, then [Lattice] section as fallback
      # Format: reduced cell plus vol=7.2218583  8.5410638 8.5902173 107.6582105 91.8679754 90.9411566 504.4382028
      cell_info = {}
      lattice_cell_info = {} # Store lattice section data as fallback
      lines_processed = 0
      in_lattice_section = false

      content.each_line.with_index do |line, index|
        lines_processed += 1
        # Clean the line
        clean_line = line.strip

        Rails.logger.debug "SCXRD: Processing line #{index + 1}: '#{clean_line}'"

        # Look for the reduced cell line first (preferred method)
        if clean_line.start_with?("reduced cell plus vol=")
          Rails.logger.info "SCXRD: Found reduced cell line at line #{index + 1}"
          cell_info = parse_cell_parameters_from_line(clean_line, "reduced cell parameters")
          # Don't break here - continue processing to ensure we find all reduced cell lines
        end

        # Check if we're entering the [Lattice] section (fallback method)
        if clean_line == "[Lattice]"
          Rails.logger.info "SCXRD: Found [Lattice] section at line #{index + 1}"
          in_lattice_section = true
          next
        end

        # Check if we're leaving the Lattice section (new section starting)
        if in_lattice_section && clean_line.start_with?("[") && clean_line != "[Lattice]"
          Rails.logger.info "SCXRD: Exiting [Lattice] section at line #{index + 1}"
          in_lattice_section = false
        end

        # If we're in the Lattice section, look for constants plus vol line (only as fallback)
        if in_lattice_section && clean_line.start_with?("constants plus vol") && cell_info.empty?
          Rails.logger.info "SCXRD: Found constants plus vol line at line #{index + 1}"
          lattice_cell_info = parse_cell_parameters_from_line(clean_line, "cell parameters from [Lattice] section")
        end
      end

      # Use reduced cell parameters if found, otherwise use lattice section as fallback
      if cell_info.empty? && !lattice_cell_info.empty?
        Rails.logger.info "SCXRD: Using [Lattice] section cell parameters as fallback"
        cell_info = lattice_cell_info
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

  def parse_cell_parameters_from_line(line, description)
    # Extract the numbers after the equals sign
    # Format: <prefix>=a b c alpha beta gamma volume
    parts = line.split("=")
    if parts.length == 2
      numbers = parts[1].strip.split(/\s+/).map(&:to_f)
      Rails.logger.info "SCXRD: Found #{numbers.length} numbers: #{numbers.inspect}"

      if numbers.length >= 6
        # First six numbers are the cell parameters
        cell_info = {
          a: numbers[0],
          b: numbers[1],
          c: numbers[2],
          alpha: numbers[3],
          beta: numbers[4],
          gamma: numbers[5]
        }

        Rails.logger.info "SCXRD: Parsed #{description}:"
        Rails.logger.info "SCXRD: a=#{cell_info[:a]}, b=#{cell_info[:b]}, c=#{cell_info[:c]}"
        Rails.logger.info "SCXRD: α=#{cell_info[:alpha]}, β=#{cell_info[:beta]}, γ=#{cell_info[:gamma]}"

        return cell_info
      else
        Rails.logger.warn "SCXRD: #{description.capitalize} line found but insufficient numbers (#{numbers.length})"
      end
    else
      Rails.logger.warn "SCXRD: #{description.capitalize} line found but couldn't parse format"
    end

    nil
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
      first_line = File.open(cmdscript_file, "r") { |f| f.readline.strip }
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
        coordinates
      else
        Rails.logger.warn "SCXRD: Could not parse coordinates from line: '#{first_line}'"
        nil
      end

    rescue => e
      Rails.logger.error "SCXRD: Error parsing cmdscript.mac file #{cmdscript_file}: #{e.message}"
      nil
    end
  end

  def parse_datacoll_ini_file(datacoll_ini_file_path)
    Rails.logger.info "SCXRD: Starting to parse datacoll.ini file: #{datacoll_ini_file_path}"

    begin
      # Check if file exists and is readable
      unless File.exist?(datacoll_ini_file_path)
        Rails.logger.error "SCXRD: datacoll.ini file does not exist: #{datacoll_ini_file_path}"
        return nil
      end

      file_size = File.size(datacoll_ini_file_path)
      Rails.logger.info "SCXRD: datacoll.ini file size: #{file_size} bytes"

      # Read the file content - datacoll.ini files are typically text files
      content = File.read(datacoll_ini_file_path, encoding: "UTF-8")
      Rails.logger.info "SCXRD: Successfully read datacoll.ini file content (#{content.length} characters)"

      # Look for the [Date] section and Start time
      measurement_time = nil
      in_date_section = false
      lines_processed = 0

      content.each_line.with_index do |line, index|
        lines_processed += 1
        # Clean the line
        clean_line = line.strip

        Rails.logger.debug "SCXRD: Processing line #{index + 1}: '#{clean_line}'"

        # Check if we're entering the [Date] section
        if clean_line == "[Date]"
          Rails.logger.info "SCXRD: Found [Date] section at line #{index + 1}"
          in_date_section = true
          next
        end

        # Check if we're leaving the Date section (new section starting)
        if in_date_section && clean_line.start_with?("[") && clean_line != "[Date]"
          Rails.logger.info "SCXRD: Exiting [Date] section at line #{index + 1}"
          in_date_section = false
        end

        # If we're in the Date section, look for Start time
        if in_date_section && clean_line.start_with?("Start time=")
          Rails.logger.info "SCXRD: Found Start time line at line #{index + 1}"

          # Extract the time string from Start time="..."
          if clean_line =~ /Start time="(.+)"/
            time_string = $1
            Rails.logger.info "SCXRD: Extracted time string: '#{time_string}'"

            begin
              # Parse the time string (format: "Tue May 13 17:58:33 2025")
              parsed_time = Time.parse(time_string)
              measurement_time = {
                measured_at: parsed_time
              }
              Rails.logger.info "SCXRD: Successfully parsed measurement time: #{parsed_time}"
              break # We found what we need
            rescue => e
              Rails.logger.warn "SCXRD: Could not parse time string '#{time_string}': #{e.message}"
            end
          else
            Rails.logger.warn "SCXRD: Start time line found but couldn't parse format: '#{clean_line}'"
          end
        end
      end

      Rails.logger.info "SCXRD: Processed #{lines_processed} lines total"

      if measurement_time.nil?
        Rails.logger.warn "SCXRD: No measurement time found in datacoll.ini file"
        nil
      else
        Rails.logger.info "SCXRD: Successfully parsed measurement time from datacoll.ini file"
        measurement_time
      end

    rescue => e
      Rails.logger.error "SCXRD: Error parsing datacoll.ini file #{datacoll_ini_file_path}: #{e.message}"
      Rails.logger.error "SCXRD: Backtrace: #{e.backtrace.first(10).join("\n")}"
      nil
    end
  end

  def extract_crystal_image
    Rails.logger.info "SCXRD: Searching for crystal image in movie folder"

    # Look for oneclickmovie*.jpg files in movie folder
    movie_folder = File.join(@folder_path, "movie")
    return unless Dir.exist?(movie_folder)

    crystal_image_pattern = File.join(movie_folder, "*.jpg")
    crystal_image_files = Dir.glob(crystal_image_pattern, File::FNM_CASEFOLD)

    Rails.logger.info "SCXRD: Found #{crystal_image_files.count} crystal image candidates: #{crystal_image_files.map { |f| File.basename(f) }.inspect}"

    if crystal_image_files.any?
      crystal_image_file = crystal_image_files.first
      Rails.logger.info "SCXRD: Using crystal image file: #{crystal_image_file}"

      begin
        @crystal_image_data = {
          data: File.binread(crystal_image_file),
          filename: File.basename(crystal_image_file),
          content_type: "image/jpeg"
        }
        Rails.logger.info "SCXRD: Crystal image extracted successfully (#{number_to_human_size(@crystal_image_data[:data].bytesize)})"
      rescue => e
        Rails.logger.error "SCXRD: Error reading crystal image file #{crystal_image_file}: #{e.message}"
        @crystal_image_data = nil
      end
    else
      Rails.logger.info "SCXRD: No crystal image files found in movie folder"
    end
  end

  def extract_structure_file
    Rails.logger.info "SCXRD: Searching for structure file in struct/best_res folder"

    # Look for .res files in struct/best_res folder recursively
    struct_folder = File.join(@folder_path, "struct", "best_res")
    unless Dir.exist?(struct_folder)
      Rails.logger.info "SCXRD: struct/best_res folder does not exist"
      return
    end

    res_file_pattern = File.join(struct_folder, "**", "*.res")
    res_files = Dir.glob(res_file_pattern, File::FNM_CASEFOLD)

    Rails.logger.info "SCXRD: Found #{res_files.count} .res files in struct/best_res: #{res_files.map { |f| File.basename(f) }.inspect}"

    if res_files.any?
      # Take the first .res file found
      structure_file = res_files.first
      Rails.logger.info "SCXRD: Using structure file: #{structure_file}"

      begin
        structure_content = File.read(structure_file, encoding: "UTF-8")

        # Determine content type based on file extension
        file_extension = File.extname(structure_file).downcase
        content_type = case file_extension
        when ".res", ".ins"
                         "chemical/x-shelx"
        when ".cif"
                         "chemical/x-cif"
        else
                         "text/plain"
        end

        @structure_file_data = {
          data: structure_content,
          filename: File.basename(structure_file),
          content_type: content_type
        }

        Rails.logger.info "SCXRD: Structure file extracted successfully: #{@structure_file_data[:filename]} (#{number_to_human_size(@structure_file_data[:data].bytesize)})"
      rescue => e
        Rails.logger.error "SCXRD: Error reading structure file #{structure_file}: #{e.message}"
        @structure_file_data = nil
      end
    else
      Rails.logger.info "SCXRD: No .res files found in struct/best_res folder"
    end
  end
end
