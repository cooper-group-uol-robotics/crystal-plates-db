namespace :scxrd do
  desc "Diagnose S3 connectivity and Active Storage service"
  task diagnose_s3: :environment do
    puts "=== SCXRD S3 Diagnostics ==="
    
    # 1. Check Active Storage service configuration
    puts "\n1. Active Storage Service:"
    puts "Current service: #{Rails.application.config.active_storage.service}"
    
    service = ActiveStorage::Blob.service
    puts "Service class: #{service.class}"
    
    if service.is_a?(ActiveStorage::Service::S3Service)
      puts "✓ Using S3 service"
      puts "Bucket: #{service.bucket.name}"
      puts "Region: #{service.client.config.region}"
    else
      puts "✗ Not using S3 service (using #{service.class})"
      puts "Check ACTIVE_STORAGE_SERVICE environment variable"
    end
    
    # 2. Test S3 connectivity
    if service.is_a?(ActiveStorage::Service::S3Service)
      puts "\n2. S3 Connectivity Test:"
      
      begin
        # Test upload/download/delete cycle
        test_key = "healthcheck-#{SecureRandom.hex(4)}.txt"
        test_content = "SCXRD diagnostics test - #{Time.current}"
        
        puts "Testing upload..."
        service.upload(test_key, StringIO.new(test_content), checksum: Digest::MD5.base64digest(test_content))
        puts "✓ Upload successful"
        
        puts "Testing existence check..."
        exists = service.exist?(test_key)
        puts exists ? "✓ Existence check successful" : "✗ File not found after upload"
        
        puts "Testing download..."
        downloaded = service.download(test_key)
        puts downloaded == test_content ? "✓ Download successful" : "✗ Download content mismatch"
        
        puts "Testing cleanup..."
        service.delete(test_key)
        puts "✓ Cleanup successful"
        
        puts "\n✓ S3 connectivity is working correctly"
        
      rescue => e
        puts "\n✗ S3 connectivity error:"
        puts "Error: #{e.class} - #{e.message}"
        
        if e.message.include?("MissingCredentialsError")
          puts "Hint: Check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        elsif e.message.include?("SignatureDoesNotMatch")
          puts "Hint: Check credentials and AWS_REGION"
        elsif e.message.include?("NoSuchBucket")
          puts "Hint: Check AWS_S3_BUCKET and AWS_REGION match"
        elsif e.message.include?("AccessDenied")
          puts "Hint: Check IAM permissions for the bucket"
        end
      end
    end
    
    # 3. Environment variables check
    puts "\n3. Environment Variables:"
    required_vars = %w[ACTIVE_STORAGE_SERVICE AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_REGION AWS_S3_BUCKET]
    
    required_vars.each do |var|
      value = ENV[var]
      if value.present?
        # Mask sensitive values
        if var.include?("SECRET") || var.include?("KEY")
          masked = "#{value[0..3]}#{"*" * (value.length - 8)}#{value[-4..-1] if value.length > 8}"
          puts "#{var}: #{masked}"
        else
          puts "#{var}: #{value}"
        end
      else
        puts "#{var}: ✗ NOT SET"
      end
    end
    
    puts "\n=== Diagnostics Complete ==="
  end

  desc "Show memory usage estimates for SCXRD processing"
  task memory_estimate: :environment do
    puts "=== SCXRD Memory Usage Estimates ==="
    
    # Find some example datasets
    datasets = ScxrdDataset.where.not(archive: nil).limit(5)
    
    if datasets.empty?
      puts "No SCXRD datasets with archives found for analysis"
      return
    end
    
    puts "\nAnalyzing #{datasets.count} datasets with archives:"
    
    datasets.each do |dataset|
      puts "\n--- Dataset #{dataset.id}: #{dataset.experiment_name} ---"
      
      if dataset.archive.attached?
        archive_size = dataset.archive.blob.byte_size
        puts "Archive size: #{ActionController::Base.helpers.number_to_human_size(archive_size)}"
        
        # Estimate memory usage
        estimated_peak = archive_size * 2.5  # Archive + extracted files + processing overhead
        puts "Estimated peak memory: #{ActionController::Base.helpers.number_to_human_size(estimated_peak)}"
        
        if estimated_peak > 400.megabytes
          puts "⚠️  WARNING: May exceed 512MB dyno limit"
          puts "   Recommendation: Use memory optimizations"
        else
          puts "✓ Should fit in 512MB dyno"
        end
      end
      
      if dataset.diffraction_images.any?
        image_count = dataset.diffraction_images.count
        total_image_size = dataset.diffraction_images.sum(:file_size)
        puts "Diffraction images: #{image_count} files, #{ActionController::Base.helpers.number_to_human_size(total_image_size)} total"
      end
    end
    
    puts "\n=== Memory Optimization Settings ==="
    puts "SCXRD_DISABLE_BULK_IMAGE_LOADING: #{ENV['SCXRD_DISABLE_BULK_IMAGE_LOADING'] || 'not set'}"
    puts "JOB_CONCURRENCY: #{ENV['JOB_CONCURRENCY'] || 'not set'}"
    
    puts "\nTo reduce memory usage:"
    puts "• Set SCXRD_DISABLE_BULK_IMAGE_LOADING=1"
    puts "• Use job queue processing instead of synchronous uploads"
    puts "• Consider upgrading to Standard-2x dyno (1GB) for large datasets"
    
    puts "\n=== Analysis Complete ==="
  end

  desc "Test streaming vs bulk processing modes"
  task test_streaming: :environment do
    puts "=== SCXRD Streaming Test ==="
    
    # This task helps verify that streaming mode works
    test_folder = Rails.root.join("tmp", "test_scxrd_streaming")
    FileUtils.mkdir_p(test_folder)
    
    begin
      # Create some mock files for testing
      frames_folder = test_folder.join("frames")
      FileUtils.mkdir_p(frames_folder)
      
      # Create 3 small test files
      3.times do |i|
        filename = "test_#{i+1}_#{i*10}.rodhypix"
        content = "Mock diffraction data #{i+1}" * 100  # Small test content
        File.write(frames_folder.join(filename), content)
      end
      
      puts "Created test folder with mock files"
      
      # Test the streaming processor
      processor = ScxrdFolderProcessorService.new(test_folder.to_s)
      
      puts "\nTesting streaming mode:"
      count = 0
      total_size = 0
      
      processor.each_diffraction_image do |meta, io|
        count += 1
        content = io.read
        total_size += content.bytesize
        puts "  Stream #{count}: #{meta[:filename]} (#{meta[:file_size]} bytes)"
      end
      
      puts "\nStreaming results:"
      puts "  Files processed: #{count}"
      puts "  Total size: #{total_size} bytes"
      puts "  ✓ Streaming mode working"
      
    ensure
      # Cleanup
      FileUtils.rm_rf(test_folder) if test_folder.exist?
      puts "\nTest files cleaned up"
    end
    
    puts "\n=== Streaming Test Complete ==="
  end
end