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
        format.html { redirect_to @well.plate, notice: "Well was successfully created." }
        format.json { render :show, status: :created, location: @well }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @well.errors, status: :unprocessable_entity }
      end
    end
  end

  # POST /wells/bulk_add_content
  def bulk_add_content
    # Parse JSON body if present
    if request.content_type == "application/json"
      json_params = JSON.parse(request.body.read)
      params.merge!(json_params)
    end

    well_ids = params[:well_ids] || params["well_ids"]
    volume_with_unit = params[:volume_with_unit] || params["volume_with_unit"]
    
    # Support both new polymorphic approach and legacy stock solution approach
    contentable_type = params[:contentable_type] || params["contentable_type"]
    contentable_id = params[:contentable_id] || params["contentable_id"]
    
    # Legacy stock solution support
    stock_solution_id = params[:stock_solution_id] || params["stock_solution_id"]

    unless well_ids.is_a?(Array) && well_ids.any?
      render json: { status: "error", message: "No wells selected" }, status: 400
      return
    end

    # Determine contentable object
    contentable = nil
    content_type_name = ""

    if contentable_type.present? && contentable_id.present?
      # New polymorphic approach
      case contentable_type
      when 'StockSolution'
        contentable = StockSolution.find_by(id: contentable_id)
        content_type_name = "stock solution"
      when 'Chemical'
        contentable = Chemical.find_by(id: contentable_id)
        content_type_name = "chemical"
      else
        render json: { status: "error", message: "Invalid content type" }, status: 400
        return
      end
    elsif stock_solution_id.present?
      # Legacy stock solution support
      contentable = StockSolution.find_by(id: stock_solution_id)
      content_type_name = "stock solution"
      contentable_type = 'StockSolution'
    else
      render json: { status: "error", message: "No content selected" }, status: 400
      return
    end

    unless contentable
      render json: { status: "error", message: "#{content_type_name.capitalize} not found" }, status: 404
      return
    end

    success_count = 0
    error_wells = []
    
    well_ids.each do |well_id|
      well = Well.find_by(id: well_id)
      if well.nil?
        error_wells << well_id
        next
      end

      # Check for existing content of the same type
      existing_content = well.well_contents.find_by(contentable: contentable)
      if existing_content
        error_wells << well_id
        next
      end

      # Create well content with polymorphic association
      well_content = well.well_contents.build(contentable: contentable)
      well_content.volume_with_unit = volume_with_unit if volume_with_unit.present?
      
      if well_content.save
        success_count += 1
      else
        error_wells << well_id
      end
    end

    if success_count > 0
      msg = "#{content_type_name.capitalize} added to #{success_count} well(s)."
      msg += " Failed for wells: #{error_wells.join(", ")}" if error_wells.any?
      render json: { status: "success", message: msg }
    else
      render json: { status: "error", message: "No wells updated. Failed for wells: #{error_wells.join(", ")}" }, status: 422
    end
  rescue JSON::ParserError
    render json: { status: "error", message: "Invalid JSON" }, status: 400
  rescue => e
    Rails.logger.error "Error in wells#bulk_add_content: #{e.message}"
    render json: { status: "error", message: "Error updating wells" }, status: 500
  end

  # PATCH/PUT /wells/1 or /wells/1.json
  def update
    respond_to do |format|
      if @well.update(well_params)
        format.html { redirect_to @well.plate, notice: "Well was successfully updated." }
        format.json { render :show, status: :ok, location: @well }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @well.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /wells/1 or /wells/1.json
  def destroy
    plate = @well.plate  # Store plate reference before destroying well
    @well.destroy!

    respond_to do |format|
      format.html { redirect_to plate, status: :see_other, notice: "Well was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def images
    @well = Well.find(params[:id])
    # Optimize query with better includes and limit recent images
    @images = @well.images
                   .includes(file_attachment: { blob: :variant_records })
                   .recent
                   .limit(50) # Limit to 50 most recent images for performance

    # Set cache headers for better client-side caching
    expires_in 5.minutes, public: false

    render partial: "images", locals: { well: @well, images: @images }
  rescue ActiveRecord::RecordNotFound
    render plain: "Well not found", status: 404
  rescue => e
    Rails.logger.error "Error in wells#images: #{e.message}"
    render plain: "Error loading images", status: 500
  end

  def spatial_correlations
    @well = Well.find(params[:id])
    tolerance_mm = params[:tolerance_mm]&.to_f || 0.5

    @correlations = ScxrdDataset.spatial_correlations_for_well(@well, tolerance_mm)

    respond_to do |format|
      format.json {
        render json: {
          well_id: @well.id,
          well_label: @well.well_label,
          tolerance_mm: tolerance_mm,
          correlations: @correlations.map do |corr|
            {
              scxrd_dataset: {
                id: corr[:scxrd_dataset].id,
                experiment_name: corr[:scxrd_dataset].experiment_name,
                coordinates: {
                  x_mm: corr[:scxrd_dataset].real_world_x_mm,
                  y_mm: corr[:scxrd_dataset].real_world_y_mm,
                  z_mm: corr[:scxrd_dataset].real_world_z_mm
                }
              },
              point_of_interests: corr[:distances].map do |dist_info|
                poi = dist_info[:poi]
                coords = poi.real_world_coordinates
                {
                  id: poi.id,
                  point_type: poi.point_type,
                  pixel_coordinates: { x: poi.pixel_x, y: poi.pixel_y },
                  real_world_coordinates: coords,
                  distance_mm: dist_info[:distance_mm].round(3),
                  image_id: poi.image_id
                }
              end
            }
          end
        }
      }
    end
  end

  def content_form
    @well = Well.find(params[:id])
    @stock_solutions = StockSolution.all.order(:name)
    @well_contents = @well.well_contents.includes(:contentable, :unit, :mass_unit)
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
      params.require(:well).permit(:plate_id, :well_row, :well_column, :subwell, :x_mm, :y_mm, :z_mm)
    end
end
