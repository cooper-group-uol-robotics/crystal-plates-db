module Api::V1
  class BaseController < ApplicationController
    # Include Pundit for authorization
    include Pundit::Authorization

    # Skip Devise authentication - API uses API key authentication instead
    skip_before_action :authenticate_user!

    # Skip CSRF token verification for API requests
    skip_before_action :verify_authenticity_token

    # Require API key authentication for all API endpoints
    before_action :authenticate_api_key!

    # Set JSON as default format
    before_action :set_default_format

    # Handle exceptions consistently
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActionController::ParameterMissing, with: :parameter_missing
    rescue_from Pundit::NotAuthorizedError, with: :not_authorized

    private

    # Authenticate API key and set current user
    def authenticate_api_key!
      token = extract_token_from_header

      if token.blank?
        render_authentication_error("API key is missing. Include it in the Authorization header as 'Bearer YOUR_API_KEY'")
        return
      end

      api_key = ApiKey.authenticate(token)

      if api_key.nil?
        render_authentication_error("Invalid or inactive API key")
        return
      end

      if api_key.expired?
        render_authentication_error("API key has expired")
        return
      end

      # Set the current user from the API key
      @current_user = api_key.user
      @current_api_key = api_key

      # Check if user is active
      unless @current_user.active?
        render_authentication_error("User account is inactive")
        nil
      end
    end

    # Extract token from Authorization header
    def extract_token_from_header
      auth_header = request.headers["Authorization"]
      return nil if auth_header.blank?

      # Expected format: "Bearer TOKEN"
      parts = auth_header.split(" ")
      return nil unless parts.length == 2 && parts[0] == "Bearer"

      parts[1]
    end

    # Current user authenticated via API key
    def current_user
      @current_user
    end

    # Current API key used for authentication
    def current_api_key
      @current_api_key
    end

    # Render authentication error
    def render_authentication_error(message)
      render json: {
        error: "Authentication failed",
        message: message
      }, status: :unauthorized
    end

    def not_authorized
      render json: {
        error: "Authorization failed",
        message: "You are not authorized to perform this action"
      }, status: :forbidden
    end

    def set_default_format
      request.format = :json
    end

    def record_not_found(exception)
      render json: {
        error: "Record not found",
        message: exception.message
      }, status: :not_found
    end

    def record_invalid(exception)
      render json: {
        error: "Validation failed",
        message: exception.message,
        details: exception.record.errors.full_messages
      }, status: :unprocessable_entity
    end

    def parameter_missing(exception)
      render json: {
        error: "Missing parameter",
        message: exception.message
      }, status: :bad_request
    end

    def render_success(data, status: :ok, message: nil)
      response = { data: data }
      response[:message] = message if message
      render json: response, status: status
    end

    def render_error(message, status: :bad_request, details: nil)
      response = { error: message }
      response[:details] = details if details
      render json: response, status: status
    end
  end
end
