module Api::V1
  class HealthController < BaseController
    def show
      render_success({
        status: "healthy",
        timestamp: Time.current,
        version: "1.0.0",
        database: database_status,
        services: {
          plates: Plate.count,
          locations: Location.count,
          wells: Well.count
        }
      })
    end

    private

    def database_status
      begin
        ActiveRecord::Base.connection.execute("SELECT 1")
        "connected"
      rescue
        "disconnected"
      end
    end
  end
end
