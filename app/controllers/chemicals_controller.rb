class ChemicalsController < ApplicationController
  before_action :set_chemical, only: %i[ show edit update destroy ]

  # GET /chemicals or /chemicals.json
  def index
    # Handle search
    @search_query = params[:search]&.strip

    # Handle sorting
    sort_column = params[:sort] || "name"
    sort_direction = params[:direction] || "asc"

    # Validate sort parameters
    allowed_columns = %w[name cas barcode sciformation_id created_at]
    sort_column = "name" unless allowed_columns.include?(sort_column)
    sort_direction = "asc" unless %w[asc desc].include?(sort_direction)

    # Start with base query
    @chemicals = Chemical.all

    # Apply search if provided
    if @search_query.present?
      @chemicals = @chemicals.where(
        "name LIKE ? OR cas LIKE ? OR barcode LIKE ?",
        "%#{@search_query}%", "%#{@search_query}%", "%#{@search_query}%"
      )
    end

    # Apply sorting
    @chemicals = @chemicals.order("#{sort_column} #{sort_direction}")

    # Add pagination
    @chemicals = @chemicals.page(params[:page]).per(25)

    @sort_column = sort_column
    @sort_direction = sort_direction

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @chemicals }
    end
  end

  # GET /chemicals/1 or /chemicals/1.json
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @chemical }
    end
  end

  # GET /chemicals/new
  def new
    @chemical = Chemical.new
  end

  # GET /chemicals/1/edit
  def edit
  end

  # POST /chemicals or /chemicals.json
  def create
    @chemical = Chemical.new(chemical_params)

    respond_to do |format|
      if @chemical.save
        format.html { redirect_to @chemical, notice: "Chemical was successfully created." }
        format.json { render :show, status: :created, location: @chemical }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @chemical.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /chemicals/1 or /chemicals/1.json
  def update
    respond_to do |format|
      if @chemical.update(chemical_params)
        format.html { redirect_to @chemical, notice: "Chemical was successfully updated." }
        format.json { render :show, status: :ok, location: @chemical }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @chemical.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /chemicals/1 or /chemicals/1.json
  def destroy
    @chemical.destroy!

    respond_to do |format|
      format.html { redirect_to chemicals_path, status: :see_other, notice: "Chemical was successfully deleted." }
      format.json { head :no_content }
    end
  end

  # POST /chemicals/import_from_sciformation
  def import_from_sciformation
    cookie = params[:sciformation_cookie]

    if cookie.blank?
      render json: { success: false, error: "Sciformation cookie is required" }, status: :bad_request
      return
    end

    begin
      result = Chemical.fetch_from_sciformation(cookie: cookie)
      render json: result
    rescue => e
      Rails.logger.error "Sciformation import error: #{e.message}"
      render json: { success: false, error: e.message }, status: :internal_server_error
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_chemical
    @chemical = Chemical.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def chemical_params
    params.require(:chemical).permit(:sciformation_id, :name, :smiles, :cas, :amount, :storage, :barcode)
  end
end
