class ScxrdDataset < ApplicationRecord
  belongs_to :well
  belongs_to :lattice_centring, optional: true
  has_one_attached :archive
  has_one_attached :peak_table
  has_one_attached :first_image

  validates :experiment_name, :date_measured, presence: true
  validates :a, :b, :c, :alpha, :beta, :gamma, numericality: { greater_than: 0 }, allow_nil: true

  def has_peak_table?
    peak_table.attached?
  end

  def has_first_image?
    first_image.attached?
  end

  def peak_table_size
    return 0 unless peak_table.attached?
    peak_table.blob.byte_size
  end

  def first_image_size
    return 0 unless first_image.attached?
    first_image.blob.byte_size
  end

  def parsed_image_data(force_refresh: false)
    return @parsed_image_data if @parsed_image_data && !force_refresh
    return nil unless has_first_image?

    Rails.logger.info "SCXRD Dataset #{id}: Parsing first image data"

    begin
      # Download the image data
      image_data = first_image.blob.download

      # Parse using the ROD parser service
      parser = RodImageParserService.new(image_data)
      @parsed_image_data = parser.parse

      Rails.logger.info "SCXRD Dataset #{id}: Image parsing #{@parsed_image_data[:success] ? 'successful' : 'failed'}"
      @parsed_image_data
    rescue => e
      Rails.logger.error "SCXRD Dataset #{id}: Error parsing image data: #{e.message}"
      {
        success: false,
        error: e.message,
        dimensions: [ 0, 0 ],
        pixel_size: [ 0.0, 0.0 ],
        image_data: [],
        metadata: {}
      }
    end
  end

  def image_dimensions
    parsed_data = parsed_image_data
    parsed_data[:dimensions] if parsed_data[:success]
  end

  def image_pixel_size
    parsed_data = parsed_image_data
    parsed_data[:pixel_size] if parsed_data[:success]
  end

  def image_metadata
    parsed_data = parsed_image_data
    parsed_data[:metadata] if parsed_data[:success]
  end

  def has_valid_image_data?
    return false unless has_first_image?
    parsed_data = parsed_image_data
    parsed_data[:success] && !parsed_data[:image_data].empty?
  end
end
