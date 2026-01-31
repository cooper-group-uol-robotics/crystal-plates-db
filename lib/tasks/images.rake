namespace :images do
  desc "Preprocess variants for all existing images"
  task preprocess_variants: :environment do
    total = Image.joins(:file_attachment).count
    puts "Found #{total} images with attachments"
    
    count = 0
    failed = 0
    
    Image.includes(file_attachment: :blob).find_each do |image|
      next unless image.file.attached?
      
      begin
        PreprocessImageVariantsJob.perform_later(image.id)
        count += 1
        print "." if count % 10 == 0
        puts " #{count}/#{total}" if count % 100 == 0
      rescue => e
        failed += 1
        puts "\nFailed to queue image #{image.id}: #{e.message}"
      end
    end
    
    puts "\n\n✓ Queued #{count} images for variant preprocessing"
    puts "✗ Failed: #{failed}" if failed > 0
    puts "\nMonitor progress with: rails jobs:work (or check your background job processor)"
  end

  desc "Check variant preprocessing status"
  task variant_status: :environment do
    total_images = Image.joins(:file_attachment).count
    
    variants_count = ActiveStorage::VariantRecord.joins(blob: :attachments)
                      .where(active_storage_attachments: { record_type: "Image" })
                      .distinct
                      .count("active_storage_attachments.record_id")
    
    puts "Image Statistics:"
    puts "  Total images: #{total_images}"
    puts "  Images with variants: #{variants_count}"
    puts "  Missing variants: #{total_images - variants_count}"
    puts ""
    
    if variants_count < total_images
      puts "To process missing variants, run: rails images:preprocess_variants"
    else
      puts "✓ All images have variants processed"
    end
    
    # Storage stats
    original_size = Image.joins(:file_attachment).sum { |img| img.file.blob.byte_size }
    variant_size = ActiveStorage::VariantRecord.joins(:blob).sum("active_storage_blobs.byte_size")
    
    puts ""
    puts "Storage Usage:"
    puts "  Original images: #{(original_size / 1.megabyte.to_f).round(2)} MB"
    puts "  Processed variants: #{(variant_size / 1.megabyte.to_f).round(2)} MB"
    puts "  Total: #{((original_size + variant_size) / 1.megabyte.to_f).round(2)} MB"
  end

  desc "Reprocess variants for specific image"
  task :reprocess, [:image_id] => :environment do |t, args|
    unless args[:image_id]
      puts "Usage: rails images:reprocess[IMAGE_ID]"
      exit 1
    end
    
    image = Image.find(args[:image_id])
    
    unless image.file.attached?
      puts "Error: Image #{image.id} has no file attached"
      exit 1
    end
    
    puts "Reprocessing variants for image #{image.id}..."
    PreprocessImageVariantsJob.perform_now(image.id)
    puts "✓ Complete"
  end

  desc "Clean up orphaned variant records"
  task cleanup_variants: :environment do
    # Find variant records where the source blob no longer exists
    orphaned = ActiveStorage::VariantRecord.left_joins(:blob)
                .where(active_storage_blobs: { id: nil })
    
    count = orphaned.count
    if count > 0
      puts "Found #{count} orphaned variant records"
      print "Delete them? (y/N) "
      response = STDIN.gets.chomp.downcase
      
      if response == "y"
        orphaned.destroy_all
        puts "✓ Deleted #{count} orphaned variant records"
      else
        puts "Cancelled"
      end
    else
      puts "✓ No orphaned variant records found"
    end
  end
end
