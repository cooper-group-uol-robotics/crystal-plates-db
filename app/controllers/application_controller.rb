class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login
  helper_method :current_user

  private

  def require_login
    return if request.env["REMOTE_USER"].present?

    request_http_basic_authentication(ENV.fetch("LDAP_AUTH_REALM", "Crystal Plates LDAP"))
  end

  def current_user
    @current_user ||= request.env["REMOTE_USER"]
  end
end
