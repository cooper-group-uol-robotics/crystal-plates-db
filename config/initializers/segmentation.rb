# Configuration for image segmentation API
Rails.application.configure do
  # URL for the external segmentation API
  # Default: http://aicdocker.liv.ac.uk:8000/segment/opencv
  # Can be overridden with SEGMENTATION_API_ENDPOINT environment variable
  config.segmentation_api_endpoint = ENV.fetch("SEGMENTATION_API_ENDPOINT", "http://aicdocker.liv.ac.uk:8000/segment/opencv")
end
