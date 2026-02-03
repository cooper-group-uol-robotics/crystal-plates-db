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

  def test_conventional_cell_api
    if ConventionalCellService.api_available?
      render json: { success: true, message: "Unit cell conversion API is available" }
    else
      render json: { success: false, message: "Unit cell conversion API is not available" }
    end
  rescue StandardError => e
    render json: { success: false, message: "Error testing unit cell conversion API: #{e.message}" }
  end

  def get_sciformation_cookie
    # Deprecated - keeping for backwards compatibility
    cookie = Setting.sciformation_cookie rescue ""
    render json: { cookie: cookie }
  end

  def test_sciformation_credentials
    # Use credentials from the request if provided, otherwise use the settings
    username = params[:username].presence || Setting.sciformation_username
    password = params[:password].presence || Setting.sciformation_password

    if username.blank? || password.blank?
      render json: {
        success: false,
        message: "Sciformation credentials not configured. Please set username and password in the settings."
      }
      return
    end

    # Test authentication with Sciformation
    begin
      service = SciformationService.new(username: username, password: password)
      service.authenticate!

      render json: {
        success: true,
        message: "Successfully authenticated with Sciformation"
      }

    rescue SciformationService::AuthenticationError => e
      render json: {
        success: false,
        message: "Authentication failed: #{e.message}"
      }
    rescue => e
      render json: {
        success: false,
        message: "Error testing Sciformation credentials: #{e.message}"
      }
    end
  end

  def test_sciformation_cookie
    # Deprecated method - redirect to test_sciformation_credentials
    render json: {
      success: false,
      message: "Cookie-based authentication is deprecated. Please use username/password authentication."
    }
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
      :auto_segment_point_type,
      :conventional_cell_api_endpoint,
      :conventional_cell_api_timeout,
      :conventional_cell_max_delta,
      :sciformation_username,
      :sciformation_password
    )
  end
end
