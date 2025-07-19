class Image < ApplicationRecord
  belongs_to :well
  has_one_attached :file
  has_many :point_of_interests, dependent: :destroy

  # Callbacks
  after_commit :populate_dimensions_if_needed, on: :create

  # Validations
  validates :pixel_size_x_mm, :pixel_size_y_mm, presence: true, numericality: { greater_than: 0 }
  validates :reference_x_mm, :reference_y_mm, :reference_z_mm, presence: true, numericality: true
  validates :file, presence: true, on: :create

  # Validate that attached file is an image
  validate :file_is_image, if: -> { file.attached? }
  validate :dimensions_available_or_extractable, if: -> { file.attached? }

  # Scopes
  scope :recent, -> { order(captured_at: :desc, created_at: :desc) }
  scope :by_capture_time, -> { order(:captured_at) }

  # Calculate physical dimensions of the image
  def physical_width_mm
    return nil unless pixel_width && pixel_size_x_mm
    pixel_width * pixel_size_x_mm
  end

  def physical_height_mm
    return nil unless pixel_height && pixel_size_y_mm
    pixel_height * pixel_size_y_mm
  end

  # Calculate the opposite corner coordinates
  def max_x_mm
    return nil unless physical_width_mm
    reference_x_mm + physical_width_mm
  end

  def max_y_mm
    return nil unless physical_height_mm
    reference_y_mm + physical_height_mm
  end

  # Get the bounding box of the image in real-world coordinates
  def bounding_box
    {
      min_x: reference_x_mm,
      min_y: reference_y_mm,
      max_x: max_x_mm,
      max_y: max_y_mm,
      z: reference_z_mm
    }
  end

  # Convert pixel coordinates to real-world coordinates
  def pixel_to_mm(pixel_x, pixel_y)
    {
      x: reference_x_mm + (pixel_x * pixel_size_x_mm),
      y: reference_y_mm + (pixel_y * pixel_size_y_mm),
      z: reference_z_mm
    }
  end

  # Convert real-world coordinates to pixel coordinates
  def mm_to_pixel(x_mm, y_mm)
    {
      x: ((x_mm - reference_x_mm) / pixel_size_x_mm).round,
      y: ((y_mm - reference_y_mm) / pixel_size_y_mm).round
    }
  end

  # Check if a real-world coordinate is within this image
  def contains_point?(x_mm, y_mm)
    x_mm >= reference_x_mm && x_mm <= max_x_mm &&
    y_mm >= reference_y_mm && y_mm <= max_y_mm
  end

  # Auto-populate pixel dimensions from attached image
  def populate_dimensions_from_file
    return false unless file.attached?
    return false unless file.blob.present?

    begin
      # Check if blob is accessible before analyzing
      return false unless file.blob.service.exist?(file.blob.key)

      # Ensure the blob is analyzed
      file.blob.analyze unless file.blob.analyzed?
      metadata = file.blob.metadata

      if metadata["width"] && metadata["height"]
        self.pixel_width = metadata["width"]
        self.pixel_height = metadata["height"]
      end
    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.warn "File not found during dimension extraction: #{e.message}"
      return false
    rescue => e
      # In test environment or when libvips is not available, use default dimensions
      if Rails.env.test? || e.message.include?("libvips") || e.message.include?("Could not open library") || e.message.include?("FileNotFoundError")
        Rails.logger.warn "Could not analyze image dimensions: #{e.message}. Using default values."
        # Don't set dimensions automatically - let validation handle this
        return false
      else
        Rails.logger.error "Unexpected error during dimension extraction: #{e.message}"
        return false
      end
    end

    # Return true if dimensions were successfully extracted
    pixel_width.present? && pixel_height.present?
  end

  private

  def populate_dimensions_if_needed
    Rails.logger.debug "populate_dimensions_if_needed callback called for image #{id}"
    # Auto-populate dimensions if they're not set and we have a file
    if file.attached? && (pixel_width.blank? || pixel_height.blank?)
      Rails.logger.debug "Attempting auto-detection: file_attached=#{file.attached?}, pixel_width=#{pixel_width}, pixel_height=#{pixel_height}"
      if populate_dimensions_from_file
        Rails.logger.debug "Auto-detection successful: #{pixel_width}x#{pixel_height}"
        # Save the updated dimensions
        update_columns(pixel_width: pixel_width, pixel_height: pixel_height)
      else
        Rails.logger.warn "Could not auto-detect dimensions for image #{id}"
      end
    else
      Rails.logger.debug "Skipping auto-detection: file_attached=#{file.attached?}, pixel_width=#{pixel_width}, pixel_height=#{pixel_height}"
    end
  end

  def dimensions_available_or_extractable
    # If both dimensions are provided manually, validate them
    if pixel_width.present? && pixel_height.present?
      unless pixel_width.is_a?(Integer) && pixel_width > 0
        errors.add(:pixel_width, "must be a positive integer")
      end
      unless pixel_height.is_a?(Integer) && pixel_height > 0
        errors.add(:pixel_height, "must be a positive integer")
      end
      return
    end

    # If neither dimension is provided, we'll try auto-detection after save
    # For now, just validate that we have a file to work with
    if pixel_width.blank? && pixel_height.blank?
      return # Allow save, auto-detection will happen after_save
    end

    # If only one dimension is provided, require both
    if pixel_width.blank? || pixel_height.blank?
      errors.add(:pixel_width, "can't be blank") if pixel_width.blank?
      errors.add(:pixel_height, "can't be blank") if pixel_height.blank?
      errors.add(:base, "Please provide both pixel width and height, or leave both blank for auto-detection")
    end
  end

  def file_is_image
    return unless file.attached?
    return unless file.blob.present?

    # Wait for the blob to be analyzed if it hasn't been yet
    begin
      # Check if blob is accessible before analyzing
      return unless file.blob.service.exist?(file.blob.key)

      file.blob.analyze unless file.blob.analyzed?

      unless file.blob.content_type&.start_with?("image/")
        errors.add(:file, "must be an image")
      end
    rescue ActiveStorage::FileNotFoundError => e
      Rails.logger.warn "File not found during validation: #{e.message}"
      errors.add(:file, "could not be found or accessed")
    rescue => e
      # In test environment or when libvips is not available, fall back to filename check
      if Rails.env.test? || e.message.include?("libvips") || e.message.include?("Could not open library")
        filename = file.blob.filename.to_s.downcase
        unless filename.match?(/\.(jpg|jpeg|png|gif|bmp|webp)$/i)
          errors.add(:file, "must be an image file (jpg, png, gif, etc.)")
        end
      else
        Rails.logger.error "Unexpected error during file validation: #{e.message}"
        errors.add(:file, "could not be processed: #{e.message}")
      end
    end
  end
end
