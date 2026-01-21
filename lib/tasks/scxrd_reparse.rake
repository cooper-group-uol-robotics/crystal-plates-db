# SCXRD Re-parsing Rake Tasks
#
# These tasks allow re-parsing of previously uploaded SCXRD dataset archives
# to extract new metadata, particularly UB matrices from *_cracker.par files.
#
# Usage:
#   bin/rails scxrd:reparse_all              # Re-parse all datasets with archives
#   bin/rails scxrd:reparse_one[123]         # Re-parse specific dataset by ID
#
# What gets updated:
#   - UB matrix (9 components from *_cracker.par)
#   - Conventional cell parameters (derived from UB via cell reduction API)
#   - Primitive cell parameters (derived from UB via cell reduction API)
#   - Measurement time (from *_datacoll.ini if different)
#   - Coordinates (from cmdscript.mac if not already set)

namespace :scxrd do
  desc "Re-parse all SCXRD datasets to extract UB matrix and updated metadata from archives"
  task reparse_all: :environment do
    puts "=" * 80
    puts "SCXRD Dataset Re-parsing Task"
    puts "=" * 80
    puts ""
    
    # Find all datasets with archives attached
    datasets_with_archives = ScxrdDataset.joins(:archive_attachment).distinct
    total_count = datasets_with_archives.count
    
    puts "Found #{total_count} SCXRD datasets with archives attached"
    puts ""
    
    if total_count == 0
      puts "No datasets to reparse. Exiting."
      exit 0
    end
    
    # Ask for confirmation
    print "Do you want to proceed with re-parsing? This will update existing data. (yes/no): "
    confirmation = STDIN.gets.strip.downcase
    
    unless confirmation == "yes" || confirmation == "y"
      puts "Operation cancelled."
      exit 0
    end
    
    puts ""
    puts "Starting re-parsing process..."
    puts "-" * 80
    
    success_count = 0
    error_count = 0
    skipped_count = 0
    ub_matrix_found_count = 0
    
    datasets_with_archives.reverse.each.with_index do |dataset, index|
      begin
        puts ""
        puts "[#{index + 1}/#{total_count}] Processing: #{dataset.experiment_name} (ID: #{dataset.id})"
        
        # Download archive to temporary location
        require "tempfile"
        require "zip"
        
        tempfile = Tempfile.new(["scxrd_archive_", ".archive"])
        tempfile.binmode
        
        begin
          # Download archive content
          dataset.archive.download do |chunk|
            tempfile.write(chunk)
          end
          tempfile.rewind
          
          # Detect and extract archive type
          Dir.mktmpdir do |extract_dir|
            archive_extracted = false
            
            # Try ZIP first
            begin
              Zip::File.open(tempfile.path) do |zip_file|
                zip_file.each do |entry|
                  next if entry.directory?
                  
                  file_path = File.join(extract_dir, entry.name)
                  FileUtils.mkdir_p(File.dirname(file_path))
                  File.open(file_path, "wb") do |f|
                    f.write(entry.get_input_stream.read)
                  end
                end
              end
              archive_extracted = true
              puts "  ✓ Extracted ZIP archive"
            rescue Zip::Error
              # Not a ZIP, try TAR
              tempfile.rewind
              
              begin
                require "rubygems/package"
                
                # Detect if it's gzipped
                tempfile.rewind
                is_gzipped = tempfile.read(2) == "\x1f\x8b".b
                tempfile.rewind
                
                io = is_gzipped ? Zlib::GzipReader.new(tempfile) : tempfile
                
                Gem::Package::TarReader.new(io) do |tar|
                  tar.each do |entry|
                    next unless entry.file?
                    
                    file_path = File.join(extract_dir, entry.full_name)
                    FileUtils.mkdir_p(File.dirname(file_path))
                    File.open(file_path, "wb") do |f|
                      f.write(entry.read)
                    end
                  end
                end
                archive_extracted = true
                puts "  ✓ Extracted TAR#{is_gzipped ? '.GZ' : ''} archive"
              rescue => tar_error
                puts "  ⚠ Could not extract archive as ZIP or TAR: #{tar_error.message}"
                puts "  - Skipping this dataset"
                skipped_count += 1
                next
              ensure
                io.close if is_gzipped && io
              end
            end
            
            unless archive_extracted
              puts "  ⚠ Failed to extract archive"
              puts "  - Skipping this dataset"
              skipped_count += 1
              next
            end
            
            # Find the experiment folder (should be the first directory in extracted files)
            experiment_folder = Dir.glob("#{extract_dir}/*").find { |path| File.directory?(path) }
            
            unless experiment_folder
              puts "  ⚠ No experiment folder found in archive"
              skipped_count += 1
              next
            end
            
            puts "  ⚠ Wiping all existing data for complete re-processing..."
            
            
            # Delete unit cell similarities (will be recomputed after save)
            dataset.unit_cell_similarities_as_dataset_1.destroy_all
            dataset.unit_cell_similarities_as_dataset_2.destroy_all
            
            # Clear all data fields (keep well_id, experiment_name, measured_at, archive)
            dataset.ub11 = nil
            dataset.ub12 = nil
            dataset.ub13 = nil
            dataset.ub21 = nil
            dataset.ub22 = nil
            dataset.ub23 = nil
            dataset.ub31 = nil
            dataset.ub32 = nil
            dataset.ub33 = nil
            dataset.wavelength = nil
            dataset.conventional_a = nil
            dataset.conventional_b = nil
            dataset.conventional_c = nil
            dataset.conventional_alpha = nil
            dataset.conventional_beta = nil
            dataset.conventional_gamma = nil
            dataset.conventional_bravais = nil
            dataset.conventional_cb_op = nil
            dataset.conventional_distance = nil
            dataset.primitive_a = nil
            dataset.primitive_b = nil
            dataset.primitive_c = nil
            dataset.primitive_alpha = nil
            dataset.primitive_beta = nil
            dataset.primitive_gamma = nil
            dataset.real_world_x_mm = nil
            dataset.real_world_y_mm = nil
            dataset.real_world_z_mm = nil
            dataset.spots_found = nil
            dataset.spots_indexed = nil
            dataset.processing_log = nil
            
            puts "  ✓ Existing data cleared"
            
            # Process the extracted folder using full service
            puts "  → Running full SCXRD folder processor..."
            service = ScxrdFolderProcessorService.new(experiment_folder)
            result = service.process
            
            # Track what we're updating
            updates = []
            
            # Extract UB matrix and cell parameters if available
            if result[:metadata]
              metadata = result[:metadata]
              
              # Check for UB matrix (new data)
              if metadata[:ub11] && metadata[:ub22] && metadata[:ub33]
                puts "  ✓ UB matrix found in archive"
                
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
                
                puts "    UB matrix: [#{dataset.ub11}, #{dataset.ub12}, #{dataset.ub13}]"
                puts "               [#{dataset.ub21}, #{dataset.ub22}, #{dataset.ub23}]"
                puts "               [#{dataset.ub31}, #{dataset.ub32}, #{dataset.ub33}]"
                puts "    Wavelength: #{dataset.wavelength} Å"
                
                ub_matrix_found_count += 1
                updates << "UB matrix"
                
                # Convert UB matrix to cell parameters
                cell_params = UbMatrixService.ub_matrix_to_cell_parameters(
                  dataset.ub11, dataset.ub12, dataset.ub13,
                  dataset.ub21, dataset.ub22, dataset.ub23,
                  dataset.ub31, dataset.ub32, dataset.ub33,
                  dataset.wavelength
                )
                
                if cell_params
                  puts "  ✓ Converted UB matrix to cell parameters"
                  
                  # Use cell reduction API to get conventional and primitive cells
                  if ConventionalCellService.enabled?
                    conventional_cells = ConventionalCellService.convert_to_conventional(
                      cell_params[:a], cell_params[:b], cell_params[:c],
                      cell_params[:alpha], cell_params[:beta], cell_params[:gamma]
                    )
                    
                    if conventional_cells && conventional_cells.any?
                      # First result is conventional cell
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
                      
                      puts "  ✓ Conventional cell: #{conventional_cell[:bravais]}"
                      puts "    a=%.3f b=%.3f c=%.3f α=%.2f° β=%.2f° γ=%.2f°" % [
                        dataset.conventional_a, dataset.conventional_b, dataset.conventional_c,
                        dataset.conventional_alpha, dataset.conventional_beta, dataset.conventional_gamma
                      ]
                      updates << "conventional cell"
                      
                      # Last result is primitive cell
                      primitive_cell = conventional_cells.last
                      dataset.primitive_a = primitive_cell[:a]
                      dataset.primitive_b = primitive_cell[:b]
                      dataset.primitive_c = primitive_cell[:c]
                      dataset.primitive_alpha = primitive_cell[:alpha]
                      dataset.primitive_beta = primitive_cell[:beta]
                      dataset.primitive_gamma = primitive_cell[:gamma]
                      
                      puts "  ✓ Primitive cell updated"
                      puts "    a=%.3f b=%.3f c=%.3f α=%.2f° β=%.2f° γ=%.2f°" % [
                        dataset.primitive_a, dataset.primitive_b, dataset.primitive_c,
                        dataset.primitive_alpha, dataset.primitive_beta, dataset.primitive_gamma
                      ]
                      updates << "primitive cell"
                    else
                      puts "  ⚠ Cell reduction API failed, storing UB-derived parameters"
                      dataset.primitive_a = cell_params[:a]
                      dataset.primitive_b = cell_params[:b]
                      dataset.primitive_c = cell_params[:c]
                      dataset.primitive_alpha = cell_params[:alpha]
                      dataset.primitive_beta = cell_params[:beta]
                      dataset.primitive_gamma = cell_params[:gamma]
                      updates << "primitive cell (from UB)"
                    end
                  else
                    puts "  ⚠ Cell reduction API disabled"
                    dataset.primitive_a = cell_params[:a]
                    dataset.primitive_b = cell_params[:b]
                    dataset.primitive_c = cell_params[:c]
                    dataset.primitive_alpha = cell_params[:alpha]
                    dataset.primitive_beta = cell_params[:beta]
                    dataset.primitive_gamma = cell_params[:gamma]
                    updates << "primitive cell (from UB)"
                  end
                else
                  puts "  ✗ Failed to convert UB matrix to cell parameters"
                end
              else
                puts "  - No UB matrix found in archive"
              end
              
              # Update measurement time if available and different
              if metadata[:measured_at] && metadata[:measured_at] != dataset.measured_at
                dataset.measured_at = metadata[:measured_at]
                updates << "measurement time"
                puts "  ✓ Updated measurement time"
              end
              
              # Update coordinates if not already set
              coords_updated = false
              if dataset.real_world_x_mm.blank? && metadata[:real_world_x_mm]
                dataset.real_world_x_mm = metadata[:real_world_x_mm]
                coords_updated = true
              end
              if dataset.real_world_y_mm.blank? && metadata[:real_world_y_mm]
                dataset.real_world_y_mm = metadata[:real_world_y_mm]
                coords_updated = true
              end
              if dataset.real_world_z_mm.blank? && metadata[:real_world_z_mm]
                dataset.real_world_z_mm = metadata[:real_world_z_mm]
                coords_updated = true
              end
              if coords_updated
                updates << "coordinates"
                puts "  ✓ Updated coordinates"
              end
            else
              puts "  - No metadata found in archive"
            end
            
            # Calculate spot statistics if we have peak table and UB matrix
            if dataset.has_peak_table? && dataset.has_ub_matrix?
              begin
                spot_stats = dataset.calculate_spot_statistics!
                if spot_stats[:spots_found] && spot_stats[:spots_indexed]
                  puts "  ✓ Spot statistics: #{spot_stats[:spots_found]} found, #{spot_stats[:spots_indexed]} indexed (#{spot_stats[:indexing_rate]}%)"
                  updates << "spot statistics"
                  
                  # Validate spot quality before keeping unit cell data
                  if spot_stats[:spots_found] < 30 || spot_stats[:indexing_rate] < 15.0
                    puts "  ⚠ Insufficient spot quality (#{spot_stats[:spots_found]} spots, #{spot_stats[:indexing_rate]}% indexed). Clearing unit cell data."
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
                    updates << "cleared unit cell (insufficient quality)"
                  else
                    puts "  ✓ Spot quality sufficient, unit cell data retained"
                  end
                elsif spot_stats[:spots_found]
                  puts "  ✓ Found #{spot_stats[:spots_found]} spots"
                  updates << "spots found"
                  puts "  ⚠ Insufficient spot quality (#{spot_stats[:spots_found]} spots. None indexed. Clearing unit cell data."
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
                  updates << "cleared unit cell (insufficient quality)"
                end
              rescue => e
                puts "  ⚠ Error calculating spot statistics: #{e.message}"
              end
            elsif dataset.has_peak_table?
              begin
                spots_found = dataset.calculate_spots_found!
                if spots_found
                  puts "  ✓ Found #{spots_found} spots (no UB matrix for indexing)"
                  updates << "spots found"
                  puts "  ⚠ Insufficient spot quality (#{spots_found} spots. None indexed. Clearing unit cell data."
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
                  updates << "cleared unit cell (insufficient quality)"
                end
              rescue => e
                puts "  ⚠ Error calculating spots found: #{e.message}"
              end
            else 
              puts "  - No peak table or UB matrix available for spot statistics. Clearing cell data."
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
              updates << "cleared unit cell (insufficient quality)"
            end
            
            # Save changes
            if updates.any?
              if dataset.save
                puts "  ✓ Saved: #{updates.join(', ')}"
                success_count += 1
              else
                puts "  ✗ Failed to save: #{dataset.errors.full_messages.join(', ')}"
                error_count += 1
              end
            else
              puts "  - No updates needed"
              skipped_count += 1
            end
          end
          
        ensure
          tempfile.close
          tempfile.unlink
        end
        
      rescue => e
        puts "  ✗ Error: #{e.message}"
        puts "     #{e.backtrace.first(3).join("\n     ")}"
        error_count += 1
      end
    end
    
    puts ""
    puts "=" * 80
    puts "Re-parsing Complete"
    puts "=" * 80
    puts "Total datasets: #{total_count}"
    puts "Successfully updated: #{success_count}"
    puts "Skipped (no changes): #{skipped_count}"
    puts "Errors: #{error_count}"
    puts ""
  end
end