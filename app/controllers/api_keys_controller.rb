class ApiKeysController < ApplicationController
  before_action :authenticate_user!
  before_action :set_api_key, only: [ :show, :destroy ]

  def index
    @api_keys = current_user.api_keys.order(created_at: :desc)
  end

  def show
    # Show individual API key details (without the raw token)
  end

  def new
    @api_key = current_user.api_keys.build
  end

  def create
    @api_key = current_user.api_keys.build(api_key_params)

    if @api_key.save
      # Store the raw token in flash to display it once
      flash[:api_key_token] = @api_key.raw_token
      flash[:notice] = "API key created successfully. Make sure to copy it now - you won't be able to see it again!"
      redirect_to api_keys_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @api_key.destroy
    flash[:notice] = "API key '#{@api_key.name}' was successfully revoked."
    redirect_to api_keys_path
  end

  private

  def set_api_key
    @api_key = current_user.api_keys.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = "API key not found."
    redirect_to api_keys_path
  end

  def api_key_params
    params.require(:api_key).permit(:name, :expires_at)
  end
end
