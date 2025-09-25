class ScxrdArchiveProcessingJob < ApplicationJob
  queue_as :default

  def perform(scxrd_dataset_id)
    dataset = ScxrdDataset.find_by(id: scxrd_dataset_id)
    return unless dataset&.archive&.attached?

    begin
      # Use the same extraction logic as before
      archive_file = dataset.archive.download
      Tempfile.create([ "uploaded_archive", ".zip" ]) do |temp_zip|
        temp_zip.binmode
        temp_zip.write(archive_file)
        temp_zip.rewind

        Dir.mktmpdir do |temp_dir|
          archive_path = temp_zip.path
          require "zip"
          Zip::File.open(archive_path) do |zip_file|
            zip_file.each do |entry|
              next if entry.directory?
              file_path = File.join(temp_dir, entry.name)
              FileUtils.mkdir_p(File.dirname(file_path))
              entry.extract(file_path)
            end
          end

          # Set experiment name from archive filename if not already set
          if dataset.experiment_name.blank? || dataset.experiment_name == "Processing..."
            base_name = File.basename(dataset.archive.filename.to_s, ".*")
            dataset.experiment_name = base_name
          end

          experiment_folder = Dir.glob("#{temp_dir}/*").find { |path| File.directory?(path) }
          if experiment_folder
            processor = ScxrdFolderProcessorService.new(experiment_folder)
            result = processor.process

            # Attach peak table
            if result[:peak_table]
              dataset.peak_table.attach(
                io: StringIO.new(result[:peak_table]),
                filename: "#{dataset.experiment_name}_peak_table.txt",
                content_type: "text/plain"
              )
            end

            # Attach diffraction images
            if result[:all_diffraction_images]&.any?
              result[:all_diffraction_images].each do |image_data|
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
              end
            end

            # Attach crystal image
            if result[:crystal_image] && !dataset.crystal_image.attached?
              dataset.crystal_image.attach(
                io: StringIO.new(result[:crystal_image][:data]),
                filename: result[:crystal_image][:filename],
                content_type: result[:crystal_image][:content_type]
              )
            end

            # Attach structure file
            if result[:structure_file] && !dataset.structure_file.attached?
              dataset.structure_file.attach(
                io: StringIO.new(result[:structure_file][:data]),
                filename: result[:structure_file][:filename],
                content_type: result[:structure_file][:content_type]
              )
            end

            # Store unit cell parameters
            if result[:par_data]
              par_data = result[:par_data]
              dataset.niggli_a = par_data[:a] if par_data[:a]
              dataset.niggli_b = par_data[:b] if par_data[:b]
              dataset.niggli_c = par_data[:c] if par_data[:c]
              dataset.niggli_alpha = par_data[:alpha] if par_data[:alpha]
              dataset.niggli_beta = par_data[:beta] if par_data[:beta]
              dataset.niggli_gamma = par_data[:gamma] if par_data[:gamma]
              if par_data[:measured_at]
                dataset.measured_at = par_data[:measured_at]
              end
            end
          end
          dataset.save!
        end
      end
    rescue => e
      Rails.logger.error "SCXRD Archive Processing Job: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    end
  end
end
