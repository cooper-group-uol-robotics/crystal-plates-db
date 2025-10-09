class ScxrdArchiveProcessingJob < ApplicationJob
  include ActionView::Helpers::NumberHelper
  queue_as :default

  def perform(scxrd_dataset_id)
    dataset = ScxrdDataset.find_by(id: scxrd_dataset_id)
    return unless dataset&.archive&.attached?

    begin
      archive_start_time = Time.current
      Rails.logger.info "SCXRD Job: Starting processing for dataset #{dataset.id}"

      # Stream archive to avoid loading entire file into memory
      archive_blob = dataset.archive.blob

      Dir.mktmpdir do |temp_dir|
        # Detect archive type from filename or content type (same as controller)
        original_filename = archive_blob.filename.to_s
        content_type = archive_blob.content_type || ""

        is_tar = original_filename.end_with?(".tar") || content_type == "application/x-tar"

        # Save the archive temporarily with correct extension - stream from blob
        archive_extension = is_tar ? ".tar" : ".zip"
        archive_path = File.join(temp_dir, "uploaded_archive#{archive_extension}")
        
        archive_blob.open do |tempfile|
          FileUtils.cp(tempfile.path, archive_path)
        end

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

          # Store all diffraction images as DiffractionImage records using streaming
          Rails.logger.info "SCXRD Job: Processing diffraction images with streaming..."
          
          image_count = 0
          total_size = 0
          
          processor.each_diffraction_image do |meta, io|
            begin
              diffraction_image = dataset.diffraction_images.build(
                run_number: meta[:run_number],
                image_number: meta[:image_number],
                filename: meta[:filename],
                file_size: meta[:file_size]
              )

              diffraction_image.rodhypix_file.attach(
                io: io,
                filename: meta[:filename],
                content_type: "application/octet-stream"
              )

              diffraction_image.save!
              image_count += 1
              total_size += meta[:file_size]

              # Log progress every 100 images to avoid log spam
              if image_count % 100 == 0
                Rails.logger.info "SCXRD Job: Stored #{image_count} diffraction images so far..."
              end

            rescue => e
              Rails.logger.error "SCXRD Job: Error storing diffraction image #{meta[:filename]}: #{e.message}"
            end
          end

          Rails.logger.info "SCXRD Job: All diffraction images stored (#{image_count} images, #{number_to_human_size(total_size)} total)"

          # Store unit cell parameters from metadata (exact same logic as controller)
          Rails.logger.info "SCXRD Job: Checking for parsed metadata..."
          if result[:metadata]
            metadata = result[:metadata]
            Rails.logger.info "SCXRD Job: Found metadata: #{metadata.inspect}"

            dataset.primitive_a = metadata[:a] if metadata[:a]
            dataset.primitive_b = metadata[:b] if metadata[:b]
            dataset.primitive_c = metadata[:c] if metadata[:c]
            dataset.primitive_alpha = metadata[:alpha] if metadata[:alpha]
            dataset.primitive_beta = metadata[:beta] if metadata[:beta]
            dataset.primitive_gamma = metadata[:gamma] if metadata[:gamma]

            Rails.logger.info "SCXRD Job: Primitive unit cell parameters stored: a=#{dataset.primitive_a}, b=#{dataset.primitive_b}, c=#{dataset.primitive_c}, α=#{dataset.primitive_alpha}, β=#{dataset.primitive_beta}, γ=#{dataset.primitive_gamma}"

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
        else
          Rails.logger.warn "SCXRD Job: No experiment folder found in extracted archive"
        end

        archive_end_time = Time.current
        Rails.logger.info "SCXRD Job: Total archive processing completed in #{(archive_end_time - archive_start_time).round(2)} seconds"
      end

      dataset.save!
    rescue Errno::ENOENT => e
      Rails.logger.error "SCXRD Archive Processing Job: Missing file - #{e.message}"
      Rails.logger.error "This might indicate an incomplete or corrupted archive upload"
      Rails.logger.error "Archive content should include all expected SCXRD files"

      # Mark dataset as having an error but don't crash the job
      if dataset
        dataset.update(experiment_name: "#{dataset.experiment_name} (Processing Error)")
      end
    rescue => e
      Rails.logger.error "SCXRD Archive Processing Job: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end

  private

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
