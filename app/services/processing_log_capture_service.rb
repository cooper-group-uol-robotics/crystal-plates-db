class ProcessingLogCaptureService
  attr_reader :logs

  def initialize
    @logs = []
  end

  def capture_logs(&block)
    @logs.clear
    log_buffer = StringIO.new

    # Create a custom logger that captures SCXRD logs
    custom_logger = Logger.new(log_buffer)
    custom_logger.level = Rails.logger.level
    custom_logger.formatter = proc do |severity, datetime, progname, msg|
      if msg.to_s.include?("SCXRD")
        formatted_log = "[#{datetime.strftime('%H:%M:%S')}] #{severity}: #{msg}"
        @logs << formatted_log
      end
      # Always write to buffer for normal logging
      "[#{datetime.strftime('%Y-%m-%d %H:%M:%S')}] #{severity}: #{msg}\n"
    end

    # Create a multi-logger that sends to both original and our custom logger
    original_rails_logger = Rails.logger
    multi_logger = MultiLogger.new([ original_rails_logger, custom_logger ])

    # Temporarily replace Rails logger
    Rails.logger = multi_logger

    begin
      result = yield
      [ result, @logs.join("\n") ]
    ensure
      # Restore original logger
      Rails.logger = original_rails_logger
    end
  end

  private

  class MultiLogger
    def initialize(loggers)
      @loggers = loggers
    end

    def add(severity, message = nil, progname = nil, &block)
      @loggers.each do |logger|
        begin
          logger.add(severity, message, progname, &block)
        rescue => e
          # Silently ignore logger errors to prevent breaking the main flow
        end
      end
    end

    def debug(message = nil, progname = nil, &block)
      add(Logger::DEBUG, message, progname, &block)
    end

    def info(message = nil, progname = nil, &block)
      add(Logger::INFO, message, progname, &block)
    end

    def warn(message = nil, progname = nil, &block)
      add(Logger::WARN, message, progname, &block)
    end

    def error(message = nil, progname = nil, &block)
      add(Logger::ERROR, message, progname, &block)
    end

    def fatal(message = nil, progname = nil, &block)
      add(Logger::FATAL, message, progname, &block)
    end

    def level
      @loggers.first.level
    end

    def level=(new_level)
      @loggers.each { |logger| logger.level = new_level }
    end
  end
end
