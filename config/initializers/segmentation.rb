# Configuration for image segmentation API
Rails.application.configure do
  # URL for the external segmentation API
  # Can be overridden with SEGMENTATION_API_ENDPOINT environment variable
  config.segmentation_api_endpoint = ENV.fetch("SEGMENTATION_API_ENDPOINT", "http://10.10.1.100:8000/segment/opencv")
end
