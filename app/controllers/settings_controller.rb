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
    cookie = Setting.sciformation_cookie
    render json: { cookie: cookie }
  end

  def test_sciformation_cookie
    # Use the cookie from the request if provided, otherwise use the settings cookie
    cookie = params[:cookie].presence || Setting.sciformation_cookie

    if cookie.blank?
      render json: {
        success: false,
        message: "Sciformation cookie not configured. Please set a valid cookie value in the settings."
      }
      return
    end

    # Test a simple request to Sciformation to verify the cookie works
    begin
      require "net/http"
      require "uri"

      uri = URI("https://sciformation.liverpool.ac.uk/performSearch")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 10
      http.open_timeout = 5

      request = Net::HTTP::Post.new(uri)
      request["Cookie"] = "SCIFORMATION=#{cookie}"

      # Test with a minimal search that should return quickly
      form_data = {
        "table" => "CdbContainer",
        "format" => "json",
        "query" => "[0]",
        "crit0" => "department",
        "op0" => "OP_IN_NUM",
        "val0" => "124"
      }
      request.set_form_data(form_data)

      response = http.request(request)

      if response.code.to_i == 200
        render json: {
          success: true,
          message: "Sciformation cookie is valid and API is accessible (HTTP #{response.code})"
        }
      else
        render json: {
          success: false,
          message: "Sciformation API returned HTTP #{response.code}. Cookie may be invalid or expired."
        }
      end

    rescue Net::TimeoutError => e
      render json: {
        success: false,
        message: "Connection timeout - Sciformation may be slow or unavailable"
      }
    rescue => e
      render json: {
        success: false,
        message: "Error testing Sciformation cookie: #{e.message}"
      }
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
      :auto_segment_point_type,
      :conventional_cell_api_endpoint,
      :conventional_cell_api_timeout,
      :conventional_cell_max_delta,
      :sciformation_cookie
    )
  end
end
