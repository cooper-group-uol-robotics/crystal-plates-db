# Configuration for Unit Cell Conversion API integration
# This API converts primitive unit cells to conventional cells for better crystallographic display
Rails.application.configure do
  # Enable/disable unit cell conversion API integration
  # Set to false to fall back to primitive cell display only
  config.conventional_cell_api_enabled = ENV.fetch("CONVENTIONAL_CELL_API_ENABLED", "true").downcase == "true"

  # Unit cell conversion API base URL
  config.conventional_cell_api_base_url = ENV.fetch("CONVENTIONAL_CELL_API_BASE_URL", "http://localhost:3001")

  # Default maximum delta for unit cell conversion tolerance
  config.conventional_cell_max_delta = ENV.fetch("CONVENTIONAL_CELL_MAX_DELTA", "1.0").to_f

  # API timeout in seconds
  config.conventional_cell_api_timeout = ENV.fetch("CONVENTIONAL_CELL_API_TIMEOUT", "5").to_i
end
