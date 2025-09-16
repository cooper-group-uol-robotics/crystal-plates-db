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
    Rails.logger.info "SCXRD: Starting folder processing for: #{@folder_path}"
    start_time = Time.current

    extract_files
    create_zip_archive

    end_time = Time.current
    Rails.logger.info "SCXRD: Folder processing completed in #{(end_time - start_time).round(2)} seconds"

    {
      peak_table: @peak_table_data,
      first_image: @first_image_data,
      zip_archive: @zip_data
    }
  end

  private

  def extract_files
    return unless Dir.exist?(@folder_path)

    Rails.logger.info "SCXRD: Extracting files from folder"

    # Find peak table file (*peakhunt.tabbin) - exclude files starting with 'pre_'
    Rails.logger.info "SCXRD: Searching for peak table files (*peakhunt.tabbin, excluding pre_*)"
    peak_table_pattern = File.join(@folder_path, "**", "*peakhunt.tabbin")
    all_peak_table_files = Dir.glob(peak_table_pattern, File::FNM_CASEFOLD)
    peak_table_files = all_peak_table_files.reject { |file| File.basename(file).start_with?("pre_") }
    Rails.logger.info "SCXRD: Found #{peak_table_files.count} peak table files (#{all_peak_table_files.count} total, #{all_peak_table_files.count - peak_table_files.count} excluded pre_* files)"

    if peak_table_files.any?
      peak_table_file = peak_table_files.first
      Rails.logger.info "SCXRD: Reading peak table file: #{File.basename(peak_table_file)}"
      @peak_table_data = File.binread(peak_table_file) if File.exist?(peak_table_file)
      Rails.logger.info "SCXRD: Peak table size: #{number_to_human_size(@peak_table_data&.bytesize || 0)}"
    end

    # Find first diffraction image (frames/*1.rodhypix) - exclude files starting with 'pre_'
    Rails.logger.info "SCXRD: Searching for first diffraction image (frames/*1.rodhypix, excluding pre_*)"
    first_image_pattern = File.join(@folder_path, "frames", "*1.rodhypix")
    all_first_image_files = Dir.glob(first_image_pattern, File::FNM_CASEFOLD)
    first_image_files = all_first_image_files.reject { |file| File.basename(file).start_with?("pre_") }
    Rails.logger.info "SCXRD: Found #{first_image_files.count} first frame files (#{all_first_image_files.count} total, #{all_first_image_files.count - first_image_files.count} excluded pre_* files)"

    if first_image_files.any?
      first_image_file = first_image_files.first
      Rails.logger.info "SCXRD: Reading first image file: #{File.basename(first_image_file)}"
      @first_image_data = File.binread(first_image_file) if File.exist?(first_image_file)
      Rails.logger.info "SCXRD: First image size: #{number_to_human_size(@first_image_data&.bytesize || 0)}"
    end

    Rails.logger.info "SCXRD: File extraction completed"
  end

  def create_zip_archive
    return unless Dir.exist?(@folder_path)

    Rails.logger.info "SCXRD: Starting ZIP archive creation"
    zip_start_time = Time.current

    # Count total files first
    total_files = count_files_recursively(@folder_path)
    Rails.logger.info "SCXRD: Total files to archive: #{total_files}"

    temp_zip = Tempfile.new([ "scxrd_archive", ".zip" ])
    temp_zip.binmode

    begin
      Zip::File.open(temp_zip.path, Zip::File::CREATE) do |zipfile|
        @file_count = 0
        add_directory_to_zip(zipfile, @folder_path, File.basename(@folder_path), total_files)
      end

      temp_zip.rewind
      @zip_data = temp_zip.read

      zip_end_time = Time.current
      Rails.logger.info "SCXRD: ZIP archive created successfully in #{(zip_end_time - zip_start_time).round(2)} seconds"
      Rails.logger.info "SCXRD: Final archive size: #{number_to_human_size(@zip_data.bytesize)}"
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
          Rails.logger.info "SCXRD: Archived #{progress} files..."
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
end
