class WellsController < ApplicationController
  before_action :set_well, only: %i[ show edit update destroy ]

  # GET /wells or /wells.json
  def index
    @wells = Well.all
  end

  # GET /wells/1 or /wells/1.json
  def show
  end

  # GET /wells/new
  def new
    @well = Well.new
  end

  # GET /wells/1/edit
  def edit
  end

  # POST /wells or /wells.json
  def create
    @well = Well.new(well_params)

    respond_to do |format|
      if @well.save
        format.html { redirect_to @well, notice: "Well was successfully created." }
        format.json { render :show, status: :created, location: @well }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @well.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /wells/1 or /wells/1.json
  def update
    respond_to do |format|
      if @well.update(well_params)
        format.html { redirect_to @well, notice: "Well was successfully updated." }
        format.json { render :show, status: :ok, location: @well }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @well.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /wells/1 or /wells/1.json
  def destroy
    @well.destroy!

    respond_to do |format|
      format.html { redirect_to wells_path, status: :see_other, notice: "Well was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def images
    @well = Well.find(params[:id])
    @images = @well.images.includes(file_attachment: :blob).recent
    render partial: "images", locals: { well: @well, images: @images }
  rescue ActiveRecord::RecordNotFound
    render plain: "Well not found", status: 404
  rescue => e
    Rails.logger.error "Error in wells#images: #{e.message}"
    render plain: "Error loading images", status: 500
  end

  def content_form
    @well = Well.find(params[:id])
    @stock_solutions = StockSolution.all.order(:name)
    @well_contents = @well.well_contents.includes(:stock_solution, :unit)
    @units = Unit.all.order(:name)
    render partial: "content_form", locals: { well: @well, stock_solutions: @stock_solutions, well_contents: @well_contents, units: @units }
  rescue ActiveRecord::RecordNotFound
    render plain: "Well not found", status: 404
  rescue => e
    Rails.logger.error "Error in wells#content_form: #{e.message}"
    render plain: "Error loading content form", status: 500
  end

  def update_content
    @well = Well.find(params[:id])

    # Parse JSON body if present
    if request.content_type == "application/json"
      json_params = JSON.parse(request.body.read)
      params.merge!(json_params)
    end

    # Remove existing content if requested
    if params[:remove_all_content] || params["remove_all_content"]
      @well.well_contents.destroy_all
      render json: { success: true, message: "All content removed" }
      return
    end

    # Add new stock solution
    stock_solution_id = params[:stock_solution_id] || params["stock_solution_id"]
    if stock_solution_id.present?
      stock_solution = StockSolution.find(stock_solution_id)

      # Check if this stock solution is already in the well
      existing_content = @well.well_contents.find_by(stock_solution: stock_solution)

      if existing_content
        render json: { success: false, message: "Stock solution already added to this well" }
      else
        # Get volume with unit parameter
        volume_with_unit = params[:volume_with_unit] || params["volume_with_unit"]

        well_content = @well.well_contents.build(stock_solution: stock_solution)
        well_content.volume_with_unit = volume_with_unit if volume_with_unit.present?

        if well_content.save
          render json: { success: true, message: "Stock solution added successfully" }
        else
          render json: { success: false, message: well_content.errors.full_messages.join(", ") }
        end
      end
    else
      render json: { success: false, message: "No stock solution selected" }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: "Well or stock solution not found" }, status: 404
  rescue JSON::ParserError
    render json: { success: false, message: "Invalid JSON" }, status: 400
  rescue => e
    Rails.logger.error "Error in wells#update_content: #{e.message}"
    render json: { success: false, message: "Error updating content" }, status: 500
  end

  def remove_content
    @well = Well.find(params[:id])
    content = @well.well_contents.find(params[:content_id])
    content.destroy!
    render json: { success: true, message: "Stock solution removed successfully" }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, message: "Content not found" }, status: 404
  rescue => e
    Rails.logger.error "Error in wells#remove_content: #{e.message}"
    render json: { success: false, message: "Error removing content" }, status: 500
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_well
      @well = Well.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def well_params
      params.require(:well).permit(:plate_id, :well_row, :well_column, :subwell)
    end
end
