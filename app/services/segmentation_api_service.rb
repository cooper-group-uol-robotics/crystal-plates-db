class SegmentationApiService
  require "faraday"
  require "faraday/multipart"

  class << self
    def segment_image(image_file)
      new(image_file).segment
    end
  end

  def initialize(image_file)
    @image_file = image_file
    @endpoint = Setting.segmentation_api_endpoint
    @timeout = Setting.segmentation_api_timeout
  end

  def segment
    response = connection.post do |req|
      req.body = { file: file_upload }
    end

    handle_response(response)
  rescue Faraday::TimeoutError
    { error: "Segmentation request timed out" }
  rescue StandardError => e
    { error: "Error during segmentation: #{e.message}" }
  end

  private

  attr_reader :image_file, :endpoint, :timeout

  def connection
    @connection ||= Faraday.new(url: endpoint) do |f|
      f.request :multipart
      f.request :url_encoded
      f.adapter Faraday.default_adapter
      f.options.timeout = timeout
    end
  end

  def file_upload
    file_io = StringIO.new
    image_file.download { |chunk| file_io.write(chunk) }
    file_io.rewind

    Faraday::Multipart::FilePart.new(
      file_io,
      image_file.content_type || "application/octet-stream",
      image_file.filename.to_s
    )
  end

  def handle_response(response)
    if response.success?
      data = JSON.parse(response.body)
      { success: true, data: data }
    else
      error_message = "API returned status #{response.status}"
      begin
        error_data = JSON.parse(response.body)
        error_message += ": #{error_data['error'] || error_data['message'] || 'Unknown error'}"
      rescue JSON::ParserError
        error_message += ": #{response.body}"
      end
      { error: error_message }
    end
  end
end
