class ChemicalsController < ApplicationController
  # ... existing methods ...

  # GET /chemicals/sciformation_auth
  def sciformation_auth
    # Store the return URL in session
    session[:return_after_auth] = chemicals_path

    # Redirect to Sciformation login
    redirect_to "https://jfb.liverpool.ac.uk/login", allow_other_host: true
  end

  # GET /chemicals/auth_callback
  def auth_callback
    # This endpoint will be called by a bookmarklet or browser extension
    # after the user authenticates with Sciformation

    cookie = params[:cookie]
    if cookie.present?
      result = Chemical.fetch_from_sciformation(cookie: cookie)
      redirect_to chemicals_path, notice: "Import completed: #{result[:imported]} chemicals imported"
    else
      redirect_to chemicals_path, alert: "Authentication failed - no cookie received"
    end
  end
end
