class ScxrdArchiveProcessingJob < ApplicationJob
  include ActionView::Helpers::NumberHelper
  queue_as :default

  def perform(scxrd_dataset_id)
    dataset = ScxrdDataset.find_by(id: scxrd_dataset_id)
    return unless dataset&.archive&.attached?

    # Capture processing logs
    log_capture_service = ProcessingLogCaptureService.new

    begin
      result, captured_logs = log_capture_service.capture_logs do
        archive_start_time = Time.current
        Rails.logger.info "SCXRD Job: Starting processing for dataset #{dataset.id}"

      # Download and extract the archive (same logic as controller)
      archive_blob = dataset.archive.blob
      archive_file = dataset.archive.download

      Dir.mktmpdir do |temp_dir|
        # Detect archive type from filename or content type (same as controller)
        original_filename = archive_blob.filename.to_s
        content_type = archive_blob.content_type || ""

        is_tar = original_filename.end_with?(".tar") || content_type == "application/x-tar"

        # Save the archive temporarily with correct extension
        archive_extension = is_tar ? ".tar" : ".zip"
        archive_path = File.join(temp_dir, "uploaded_archive#{archive_extension}")
        File.open(archive_path, "wb") { |f| f.write(archive_file) }

        # Extract the archive using same methods as controller
        extract_start_time = Time.current
        file_count = 0

        if is_tar
          Rails.logger.info "SCXRD Job: Extracting TAR archive..."
          file_count = extract_tar_archive(archive_path, temp_dir)
        else
          Rails.logger.info "SCXRD Job: Extracting ZIP archive..."
          file_count = extract_zip_archive(archive_path, temp_dir)
        end

        Rails.logger.info "SCXRD Job: Extracted #{file_count} files in #{(Time.current - extract_start_time).round(2)}s"

        # Set experiment name from archive filename if not already set
        if dataset.experiment_name.blank? || dataset.experiment_name == "Processing..."
          base_name = File.basename(archive_blob.filename.to_s, ".*")
          dataset.experiment_name = base_name
        end

        # Find the experiment folder (should be the first directory in the extracted files)
        experiment_folder = Dir.glob("#{temp_dir}/*").find { |path| File.directory?(path) }
        if experiment_folder
          Rails.logger.info "SCXRD Job: Processing experiment folder: #{experiment_folder}"

          processor = ScxrdFolderProcessorService.new(experiment_folder)
          result = processor.process

          Rails.logger.info "SCXRD Job: File processing completed, storing results..."

          # Store extracted data as Active Storage attachments (exact same logic as controller)
          if result[:peak_table]
            dataset.peak_table.attach(
              io: StringIO.new(result[:peak_table]),
              filename: "#{dataset.experiment_name}_peak_table.txt",
              content_type: "text/plain"
            )
            Rails.logger.info "SCXRD Job: Peak table stored (#{number_to_human_size(result[:peak_table].bytesize)})"
          end



          # Store UB matrix and derive unit cell parameters
          Rails.logger.info "SCXRD Job: Checking for parsed metadata..."
          if result[:metadata]
            metadata = result[:metadata]
            Rails.logger.info "SCXRD Job: Found metadata: #{metadata.inspect}"

            # Check for UB matrix (preferred source of truth)
            if metadata[:ub11] && metadata[:ub22] && metadata[:ub33]
              Rails.logger.info "SCXRD Job: UB matrix found, using as source of truth"
              
              # Store UB matrix
              dataset.ub11 = metadata[:ub11]
              dataset.ub12 = metadata[:ub12]
              dataset.ub13 = metadata[:ub13]
              dataset.ub21 = metadata[:ub21]
              dataset.ub22 = metadata[:ub22]
              dataset.ub23 = metadata[:ub23]
              dataset.ub31 = metadata[:ub31]
              dataset.ub32 = metadata[:ub32]
              dataset.ub33 = metadata[:ub33]
              dataset.wavelength = metadata[:wavelength]
              
              Rails.logger.info "SCXRD Job: UB matrix stored (wavelength: #{dataset.wavelength} Å)"
              
              # Convert UB matrix to cell parameters
              cell_params = UbMatrixService.ub_matrix_to_cell_parameters(
                dataset.ub11, dataset.ub12, dataset.ub13,
                dataset.ub21, dataset.ub22, dataset.ub23,
                dataset.ub31, dataset.ub32, dataset.ub33,
                dataset.wavelength
              )
              
              if cell_params
                Rails.logger.info "SCXRD Job: Cell parameters from UB matrix: a=#{cell_params[:a]}, b=#{cell_params[:b]}, c=#{cell_params[:c]}, α=#{cell_params[:alpha]}, β=#{cell_params[:beta]}, γ=#{cell_params[:gamma]}"
                
                # Use cell reduction API to get conventional and primitive cells
                # Call once and store both results
                if ConventionalCellService.enabled?
                  conventional_cells = ConventionalCellService.convert_to_conventional(
                    cell_params[:a], cell_params[:b], cell_params[:c],
                    cell_params[:alpha], cell_params[:beta], cell_params[:gamma]
                  )
                  
                  if conventional_cells && conventional_cells.any?
                    # First result is conventional cell (highest symmetry)
                    conventional_cell = conventional_cells.first
                    dataset.conventional_a = conventional_cell[:a]
                    dataset.conventional_b = conventional_cell[:b]
                    dataset.conventional_c = conventional_cell[:c]
                    dataset.conventional_alpha = conventional_cell[:alpha]
                    dataset.conventional_beta = conventional_cell[:beta]
                    dataset.conventional_gamma = conventional_cell[:gamma]
                    dataset.conventional_bravais = conventional_cell[:bravais]
                    dataset.conventional_cb_op = conventional_cell[:cb_op]
                    dataset.conventional_distance = conventional_cell[:distance]
                    
                    Rails.logger.info "SCXRD Job: Conventional cell stored: #{conventional_cell[:bravais]} a=#{dataset.conventional_a}, b=#{dataset.conventional_b}, c=#{dataset.conventional_c}"
                    
                    # Last result is primitive cell
                    primitive_cell = conventional_cells.last
                    dataset.primitive_a = primitive_cell[:a]
                    dataset.primitive_b = primitive_cell[:b]
                    dataset.primitive_c = primitive_cell[:c]
                    dataset.primitive_alpha = primitive_cell[:alpha]
                    dataset.primitive_beta = primitive_cell[:beta]
                    dataset.primitive_gamma = primitive_cell[:gamma]
                    
                    Rails.logger.info "SCXRD Job: Primitive cell stored: #{primitive_cell[:bravais]} a=#{dataset.primitive_a}, b=#{dataset.primitive_b}, c=#{dataset.primitive_c}"
                  else
                    Rails.logger.warn "SCXRD Job: Cell reduction API failed, storing UB-derived parameters as primitive"
                    dataset.primitive_a = cell_params[:a]
                    dataset.primitive_b = cell_params[:b]
                    dataset.primitive_c = cell_params[:c]
                    dataset.primitive_alpha = cell_params[:alpha]
                    dataset.primitive_beta = cell_params[:beta]
                    dataset.primitive_gamma = cell_params[:gamma]
                  end
                else
                  Rails.logger.warn "SCXRD Job: Cell reduction API disabled, storing UB-derived parameters as primitive"
                  dataset.primitive_a = cell_params[:a]
                  dataset.primitive_b = cell_params[:b]
                  dataset.primitive_c = cell_params[:c]
                  dataset.primitive_alpha = cell_params[:alpha]
                  dataset.primitive_beta = cell_params[:beta]
                  dataset.primitive_gamma = cell_params[:gamma]
                end
              else
                Rails.logger.error "SCXRD Job: Failed to convert UB matrix to cell parameters"
              end
            # Fallback: Extract unit cell parameters from crystal.ini (old method)
            elsif metadata[:a] && metadata[:b] && metadata[:c] && metadata[:alpha] && metadata[:beta] && metadata[:gamma]
              original_a = metadata[:a]
              original_b = metadata[:b]
              original_c = metadata[:c]
              original_alpha = metadata[:alpha]
              original_beta = metadata[:beta]
              original_gamma = metadata[:gamma]

              Rails.logger.info "SCXRD Job: Using fallback crystal.ini cell parameters: a=#{original_a}, b=#{original_b}, c=#{original_c}, α=#{original_alpha}, β=#{original_beta}, γ=#{original_gamma}"

              # Convert to primitive cell using the PrimitiveCellService
              if PrimitiveCellService.enabled?
                primitive_cell = PrimitiveCellService.ensure_primitive(
                  original_a, original_b, original_c,
                  original_alpha, original_beta, original_gamma
                )

                if primitive_cell
                  dataset.primitive_a = primitive_cell[:a]
                  dataset.primitive_b = primitive_cell[:b]
                  dataset.primitive_c = primitive_cell[:c]
                  dataset.primitive_alpha = primitive_cell[:alpha]
                  dataset.primitive_beta = primitive_cell[:beta]
                  dataset.primitive_gamma = primitive_cell[:gamma]

                  Rails.logger.info "SCXRD Job: Primitive unit cell parameters stored: a=#{dataset.primitive_a}, b=#{dataset.primitive_b}, c=#{dataset.primitive_c}, α=#{dataset.primitive_alpha}, β=#{dataset.primitive_beta}, γ=#{dataset.primitive_gamma}"
                else
                  Rails.logger.warn "SCXRD Job: Failed to convert to primitive cell, storing original parameters"
                  dataset.primitive_a = original_a
                  dataset.primitive_b = original_b
                  dataset.primitive_c = original_c
                  dataset.primitive_alpha = original_alpha
                  dataset.primitive_beta = original_beta
                  dataset.primitive_gamma = original_gamma
                end
              else
                Rails.logger.warn "SCXRD Job: PrimitiveCellService is disabled, storing original parameters"
                dataset.primitive_a = original_a
                dataset.primitive_b = original_b
                dataset.primitive_c = original_c
                dataset.primitive_alpha = original_alpha
                dataset.primitive_beta = original_beta
                dataset.primitive_gamma = original_gamma
              end
            else
              Rails.logger.warn "SCXRD Job: No UB matrix or unit cell parameters found in metadata"
            end

            # Store real world coordinates if parsed, but only if not already provided by user
            parsed_coords_used = false

            if dataset.real_world_x_mm.blank? && metadata[:real_world_x_mm]
              dataset.real_world_x_mm = metadata[:real_world_x_mm]
              parsed_coords_used = true
            end

            if dataset.real_world_y_mm.blank? && metadata[:real_world_y_mm]
              dataset.real_world_y_mm = metadata[:real_world_y_mm]
              parsed_coords_used = true
            end

            if dataset.real_world_z_mm.blank? && metadata[:real_world_z_mm]
              dataset.real_world_z_mm = metadata[:real_world_z_mm]
              parsed_coords_used = true
            end

            if parsed_coords_used
              Rails.logger.info "SCXRD Job: Real world coordinates from cmdscript.mac used: x=#{dataset.real_world_x_mm}, y=#{dataset.real_world_y_mm}, z=#{dataset.real_world_z_mm}"
            elsif metadata[:real_world_x_mm] || metadata[:real_world_y_mm] || metadata[:real_world_z_mm]
              Rails.logger.info "SCXRD Job: Real world coordinates ignored (user provided values take precedence)"
            end

            # Store measurement time from datacoll.ini if available (takes precedence over default)
            if metadata[:measured_at]
              dataset.measured_at = metadata[:measured_at]
              Rails.logger.info "SCXRD Job: Measurement time from datacoll.ini: #{dataset.measured_at}"
            end
          else
            Rails.logger.warn "SCXRD Job: No metadata found in processing result"
          end

          # Store crystal image if available and no image is already attached (exact same logic)
          if result[:crystal_image] && !dataset.crystal_image.attached?
            Rails.logger.info "SCXRD Job: Attaching crystal image from archive (#{number_to_human_size(result[:crystal_image][:data].bytesize)})"
            dataset.crystal_image.attach(
              io: StringIO.new(result[:crystal_image][:data]),
              filename: result[:crystal_image][:filename],
              content_type: result[:crystal_image][:content_type]
            )

            # Create well image if dataset is associated with a well and has coordinates
            create_well_image_from_crystal_image(dataset, result)
          elsif result[:crystal_image]
            Rails.logger.info "SCXRD Job: Crystal image found but dataset already has one attached, skipping"
          end

          # Store structure file if available and no structure file is already attached (exact same logic)
          if result[:structure_file] && !dataset.structure_file.attached?
            Rails.logger.info "SCXRD Job: Attaching structure file from archive: #{result[:structure_file][:filename]} (#{number_to_human_size(result[:structure_file][:data].bytesize)})"
            dataset.structure_file.attach(
              io: StringIO.new(result[:structure_file][:data]),
              filename: result[:structure_file][:filename],
              content_type: result[:structure_file][:content_type]
            )
          elsif result[:structure_file]
            Rails.logger.info "SCXRD Job: Structure file found but dataset already has one attached, skipping"
          end

          # Store all diffraction images as DiffractionImage records (exact same logic)
          if result[:all_diffraction_images] && result[:all_diffraction_images].any?
            Rails.logger.info "SCXRD Job: Processing #{result[:all_diffraction_images].length} diffraction images..."

            result[:all_diffraction_images].each_with_index do |image_data, index|
              begin
                diffraction_image = dataset.diffraction_images.build(
                  run_number: image_data[:run_number],
                  image_number: image_data[:image_number],
                  filename: image_data[:filename],
                  file_size: image_data[:file_size]
                )

                diffraction_image.rodhypix_file.attach(
                  io: StringIO.new(image_data[:data]),
                  filename: image_data[:filename],
                  content_type: "application/octet-stream"
                )

                diffraction_image.save!

                # Log progress every 100 images to avoid log spam
                if (index + 1) % 100 == 0 || index == result[:all_diffraction_images].length - 1
                  Rails.logger.info "SCXRD Job: Stored #{index + 1}/#{result[:all_diffraction_images].length} diffraction images"
                end

              rescue => e
                Rails.logger.error "SCXRD Job: Error storing diffraction image #{image_data[:filename]}: #{e.message}"
              end
            end

            total_size = result[:all_diffraction_images].sum { |img| img[:file_size] }
            Rails.logger.info "SCXRD Job: All diffraction images stored (#{result[:all_diffraction_images].length} images, #{number_to_human_size(total_size)} total)"
          end
        else
          Rails.logger.warn "SCXRD Job: No experiment folder found in extracted archive"
        end

        archive_end_time = Time.current
        Rails.logger.info "SCXRD Job: Total archive processing completed in #{(archive_end_time - archive_start_time).round(2)} seconds"
      end

      "processing_completed" # Return a value for the captured logs
      end

      # Save the dataset first so Active Storage attachments are persisted
      dataset.processing_log = captured_logs
      dataset.save!
      
      # Now calculate spot statistics with persisted attachments
      if dataset.has_peak_table? && dataset.has_ub_matrix?
        Rails.logger.info "SCXRD Job: Calculating spot statistics..."
        begin
          spot_stats = dataset.calculate_spot_statistics!
          Rails.logger.info "SCXRD Job: Spot statistics: #{spot_stats[:spots_found]} spots found, #{spot_stats[:spots_indexed]} indexed (#{spot_stats[:indexing_rate]}%)"
          
          # Validate spot quality before keeping unit cell data
          if spot_stats[:spots_found] < 30 || spot_stats[:indexing_rate] < 15.0
            Rails.logger.warn "SCXRD Job: Insufficient spot quality (#{spot_stats[:spots_found]} spots, #{spot_stats[:indexing_rate]}% indexed). Clearing unit cell data."
            dataset.primitive_a = nil
            dataset.primitive_b = nil
            dataset.primitive_c = nil
            dataset.primitive_alpha = nil
            dataset.primitive_beta = nil
            dataset.primitive_gamma = nil
            dataset.conventional_a = nil
            dataset.conventional_b = nil
            dataset.conventional_c = nil
            dataset.conventional_alpha = nil
            dataset.conventional_beta = nil
            dataset.conventional_gamma = nil
            dataset.conventional_bravais = nil
            dataset.conventional_distance = nil
            dataset.save! # Save the cleared data
          else
            Rails.logger.info "SCXRD Job: Spot quality sufficient, unit cell data retained"
          end
        rescue => e
          Rails.logger.error "SCXRD Job: Error calculating spot statistics: #{e.message}"
        end
      elsif dataset.has_peak_table?
        Rails.logger.info "SCXRD Job: Calculating spots found (no UB matrix available for indexing calculation)..."
        begin
          spots_found = dataset.calculate_spots_found!
          Rails.logger.info "SCXRD Job: Found #{spots_found} spots" if spots_found
          Rails.logger.warn "SCXRD Job: Insufficient spot quality (#{spots_found} spots, none indexed). Clearing unit cell data."
          dataset.primitive_a = nil
          dataset.primitive_b = nil
          dataset.primitive_c = nil
          dataset.primitive_alpha = nil
          dataset.primitive_beta = nil
          dataset.primitive_gamma = nil
          dataset.conventional_a = nil
          dataset.conventional_b = nil
          dataset.conventional_c = nil
          dataset.conventional_alpha = nil
          dataset.conventional_beta = nil
          dataset.conventional_gamma = nil
          dataset.conventional_bravais = nil
          dataset.conventional_distance = nil
          dataset.save! # Save the cleared data
        rescue => e
          Rails.logger.error "SCXRD Job: Error calculating spots found: #{e.message}"
        end
      else
        Rails.logger.warn "SCXRD Job: No peak table or UB matrix available. Clearing unit cell data."
        dataset.primitive_a = nil
        dataset.primitive_b = nil
        dataset.primitive_c = nil
        dataset.primitive_alpha = nil
        dataset.primitive_beta = nil
        dataset.primitive_gamma = nil
        dataset.conventional_a = nil
        dataset.conventional_b = nil
        dataset.conventional_c = nil
        dataset.conventional_alpha = nil
        dataset.conventional_beta = nil
        dataset.conventional_gamma = nil
        dataset.conventional_bravais = nil
        dataset.conventional_distance = nil
        dataset.save! # Save the cleared data
      end
    rescue Errno::ENOENT => e
      error_logs = [
        "SCXRD Archive Processing Job: Missing file - #{e.message}",
        "This might indicate an incomplete or corrupted archive upload",
        "Archive content should include all expected SCXRD files"
      ].join("\n")

      Rails.logger.error error_logs

      # Mark dataset as having an error and save error logs
      if dataset
        dataset.update(
          experiment_name: "#{dataset.experiment_name} (Processing Error)",
          processing_log: error_logs
        )
      end
    rescue => e
      error_logs = [
        "SCXRD Archive Processing Job: #{e.class} - #{e.message}",
        e.backtrace.join("\n")
      ].join("\n")

      Rails.logger.error error_logs

      # Save error logs to dataset
      if dataset
        dataset.update(processing_log: error_logs)
      end
    end
  end

  private

  # Create a well image from the crystal image if the SCXRD dataset is associated with a well
  # and has real-world coordinates from the cmdscript.mac file
  def create_well_image_from_crystal_image(scxrd_dataset, processing_result)
    return unless scxrd_dataset.well.present?
    return unless processing_result[:crystal_image]
    return unless processing_result[:metadata]

    # Check if we have real-world coordinates from cmdscript.mac
    metadata = processing_result[:metadata]
    return unless metadata[:real_world_x_mm] && metadata[:real_world_y_mm] && metadata[:real_world_z_mm]

    Rails.logger.info "SCXRD Job: Creating well image from crystal image for dataset #{scxrd_dataset.id}"

    begin
      # Get image dimensions directly from the extracted image data to avoid race conditions
      crystal_image_data = processing_result[:crystal_image]
      
      # Analyze the image data directly using MiniMagick to get dimensions
      require 'mini_magick'
      begin
        image = MiniMagick::Image.read(crystal_image_data[:data])
        pixel_width = image.width
        pixel_height = image.height
        Rails.logger.info "SCXRD Job: Crystal image dimensions from extracted data: #{pixel_width}x#{pixel_height}"
      rescue => e
        Rails.logger.error "SCXRD Job: Failed to analyze crystal image data with MiniMagick: #{e.message}"
        return
      end

      unless pixel_width && pixel_height
        Rails.logger.warn "SCXRD Job: Could not determine crystal image dimensions, skipping well image creation"
        return
      end

      # Calculate reference point using the service method
      # The coordinates from cmdscript.mac refer to the center of the image
      reference_data = ScxrdFolderProcessorService.calculate_well_image_reference_point(
        metadata[:real_world_x_mm],
        metadata[:real_world_y_mm],
        metadata[:real_world_z_mm],
        pixel_width,
        pixel_height
      )

      Rails.logger.info "SCXRD Job: Calculated reference point: x=#{reference_data[:reference_x_mm]}, y=#{reference_data[:reference_y_mm]}, z=#{reference_data[:reference_z_mm]}"

      # Create the well image
      well_image = scxrd_dataset.well.images.build(
        pixel_size_x_mm: reference_data[:pixel_size_x_mm],
        pixel_size_y_mm: reference_data[:pixel_size_y_mm],
        reference_x_mm: reference_data[:reference_x_mm],
        reference_y_mm: reference_data[:reference_y_mm],
        reference_z_mm: reference_data[:reference_z_mm],
        pixel_width: pixel_width,
        pixel_height: pixel_height,
        description: "Crystal image from SCXRD dataset: #{scxrd_dataset.experiment_name}",
        captured_at: scxrd_dataset.measured_at
      )

      # Attach the same image data to the well image
      well_image.file.attach(
        io: StringIO.new(crystal_image_data[:data]),
        filename: "scxrd_crystal_#{scxrd_dataset.experiment_name}.#{crystal_image_data[:filename].split('.').last}",
        content_type: crystal_image_data[:content_type]
      )

      if well_image.save
        Rails.logger.info "SCXRD Job: Successfully created well image #{well_image.id} for well #{scxrd_dataset.well.id}"
        
        # Create a point of interest at the center of the image
        center_x = pixel_width / 2.0
        center_y = pixel_height / 2.0
        
        point_of_interest = well_image.point_of_interests.build(
          pixel_x: center_x,
          pixel_y: center_y,
          point_type: 'measured',
        )
        
        if point_of_interest.save
          Rails.logger.info "SCXRD Job: Successfully created point of interest at center (#{center_x}, #{center_y}) for well image #{well_image.id}"
        else
          Rails.logger.error "SCXRD Job: Failed to create point of interest: #{point_of_interest.errors.full_messages.join(', ')}"
        end
      else
        Rails.logger.error "SCXRD Job: Failed to create well image: #{well_image.errors.full_messages.join(', ')}"
      end

    rescue => e
      Rails.logger.error "SCXRD Job: Error creating well image from crystal image: #{e.message}"
      Rails.logger.error "SCXRD Job: Backtrace: #{e.backtrace.first(3).join("\n")}"
    end
  end

  # Extract ZIP archive using rubyzip InputStream
  def extract_zip_archive(archive_path, temp_dir)
    require "zip"
    file_count = 0

    File.open(archive_path, "rb") do |file|
      Zip::InputStream.open(file) do |zip_stream|
        while (entry = zip_stream.get_next_entry)
          file_path = File.join(temp_dir, entry.name)

          if entry.directory?
            # Create directory
            FileUtils.mkdir_p(file_path)
          else
            # Create parent directories
            FileUtils.mkdir_p(File.dirname(file_path))

            # Extract file content
            File.open(file_path, "wb") do |output_file|
              output_file.write(zip_stream.read)
            end

            file_count += 1
          end
        end
      end
    end

    file_count
  end

  # Ruby-based TAR extraction
  def extract_tar_archive(archive_path, temp_dir)
    file_count = 0

    File.open(archive_path, "rb") do |tar_file|
      while !tar_file.eof?
        # Read TAR header (512 bytes)
        header = tar_file.read(512)
        break if header.nil? || header.length < 512

        # Check if this is the end of the archive (all zeros)
        break if header.unpack("C*").all?(&:zero?)

        # Parse TAR header
        filename = header[0, 100].unpack("Z*")[0]
        size_octal = header[124, 12].unpack("Z*")[0]

        next if filename.empty?

        file_size = size_octal.to_i(8)

        # Skip directories
        unless filename.end_with?("/")
          # Create directory path
          file_path = File.join(temp_dir, filename)
          FileUtils.mkdir_p(File.dirname(file_path))

          # Read and write file content
          if file_size > 0
            content = tar_file.read(file_size)
            File.open(file_path, "wb") { |f| f.write(content) }
            file_count += 1
          end

          # Skip to next 512-byte boundary
          remainder = file_size % 512
          tar_file.read(512 - remainder) if remainder > 0
        else
          # Skip directory content (should be 0)
          remainder = file_size % 512
          tar_file.read(file_size + (remainder > 0 ? 512 - remainder : 0))
        end
      end
    end

    file_count
  end
end
