# Configuration for image segmentation API
Rails.application.configure do
  # URL for the external segmentation API
  # Now managed via database settings (see Settings model)
  # Fallback to environment variable if database is not available (e.g., during migrations)
  config.segmentation_api_endpoint = begin
    Setting.segmentation_api_endpoint if defined?(Setting) && Setting.table_exists?
  rescue
    nil
  end || ENV.fetch("SEGMENTATION_API_ENDPOINT", "http://aicdocker.liv.ac.uk:8000/segment/opencv")
end
