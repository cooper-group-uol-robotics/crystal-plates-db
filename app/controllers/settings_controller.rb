class SettingsController < ApplicationController
  before_action :set_settings, only: [ :show, :index, :update ]

  def show
    redirect_to settings_path
  end

  def index
    # This will render the settings form
  end

  def update
    success_count = 0
    error_messages = []

    setting_params.each do |key, value|
      begin
        Setting.set(key, value)
        success_count += 1
      rescue StandardError => e
        error_messages << "Failed to update #{key}: #{e.message}"
      end
    end

    if error_messages.empty?
      redirect_to settings_path, notice: "Successfully updated #{success_count} setting(s)"
    else
      redirect_to settings_path, alert: "Some settings failed to update: #{error_messages.join(', ')}"
    end
  end

  def test_connection
    endpoint = params[:endpoint] || Setting.segmentation_api_endpoint
    timeout = params[:timeout]&.to_i || Setting.segmentation_api_timeout

    begin
      require "faraday"

      uri = URI.parse(endpoint)
      base_url = "#{uri.scheme}://#{uri.host}"
      base_url += ":#{uri.port}" if uri.port && ![ 80, 443 ].include?(uri.port)
      conn = Faraday.new(url: "#{base_url}/health") do |f|
        f.adapter Faraday.default_adapter
        f.options.timeout = timeout
        f.options.open_timeout = 5
      end

      response = conn.get

      if response.status < 400
        render json: {
          success: true,
          message: "Connection successful (HTTP #{response.status})",
          status: response.status
        }
      else
        render json: {
          success: false,
          message: "Connection failed with HTTP #{response.status}",
          status: response.status
        }
      end
    rescue Faraday::ConnectionFailed => e
      render json: {
        success: false,
        message: "Connection failed: #{e.message}"
      }
    rescue Faraday::TimeoutError => e
      render json: {
        success: false,
        message: "Connection timed out: #{e.message}"
      }
    rescue StandardError => e
      render json: {
        success: false,
        message: "Error: #{e.message}"
      }
    end
  end

  private

  def set_settings
    # Initialize defaults if needed
    Setting.initialize_defaults!
    @settings = Setting.all.index_by(&:key)
  end

  def setting_params
    params.require(:settings).permit(
      :segmentation_api_endpoint,
      :segmentation_api_timeout,
      :auto_segment_point_type
    )
  end
end
