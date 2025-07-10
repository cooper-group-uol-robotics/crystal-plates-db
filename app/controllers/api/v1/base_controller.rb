module Api::V1
  class BaseController < ApplicationController
    # Skip CSRF token verification for API requests
    skip_before_action :verify_authenticity_token

    # Set JSON as default format
    before_action :set_default_format

    # Handle exceptions consistently
    rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
    rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
    rescue_from ActionController::ParameterMissing, with: :parameter_missing

    private

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
