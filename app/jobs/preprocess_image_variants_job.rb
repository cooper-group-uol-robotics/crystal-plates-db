class PreprocessImageVariantsJob < ApplicationJob
  queue_as :default

  retry_on ActiveStorage::FileNotFoundError, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::RecordNotFound, attempts: 1

  def perform(image_id)
    image = Image.find(image_id)
    
    unless image.file.attached?
      Rails.logger.warn "Image #{image_id} has no file attached, skipping variant preprocessing"
      return
    end

    Rails.logger.info "Preprocessing variants for image #{image_id}"
    
    # Process each variant - this will create and store them in S3
    [ :thumb, :medium, :large ].each do |variant_name|
      begin
        processed_variant = image.file.variant(variant_name).processed
        Rails.logger.info "  ✓ Processed #{variant_name} variant (#{processed_variant.blob.byte_size} bytes)"
      rescue => e
        Rails.logger.error "  ✗ Failed to process #{variant_name} variant: #{e.message}"
        raise if variant_name == :thumb # Fail job if thumbnail processing fails
      end
    end

    Rails.logger.info "Completed preprocessing variants for image #{image_id}"
  end
end
