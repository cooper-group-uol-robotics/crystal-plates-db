# Solid Queue configuration for production deployment
if Rails.env.production?
  Rails.application.configure do
    # Ensure Solid Queue is the active job adapter
    config.active_job.queue_adapter = :solid_queue
    
    # Configure database connection for Solid Queue
    config.solid_queue.connects_to = { database: { writing: :queue } }
    
    # Set default queue for jobs if not specified
    config.active_job.default_queue_name = :default
    
    # Configure logging for better debugging
    config.active_job.logger = Rails.logger
    
    # Retry configuration
    config.active_job.retry_jitter = 0.15
  end
  
  # Log Solid Queue startup
  Rails.logger.info "🚀 Solid Queue configured for production"
end