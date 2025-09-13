class PointOfInterestsController < ApplicationController
  before_action :set_well_and_image
  before_action :set_point_of_interest, only: [ :show, :update, :destroy ]

  # GET /wells/:well_id/images/:image_id/point_of_interests
  def index
    @points = @image.point_of_interests.recent

    respond_to do |format|
      format.html { redirect_to well_image_path(@well, @image) }
      format.json do
        result = @points.map do |point|
          {
            id: point.id,
            pixel_x: point.pixel_x,
            pixel_y: point.pixel_y,
            real_world_x_mm: point.real_world_x_mm,
            real_world_y_mm: point.real_world_y_mm,
            real_world_z_mm: point.real_world_z_mm,
            point_type: point.point_type,
            description: point.description,
            marked_at: point.marked_at,
            display_name: point.display_name
          }
        end

        render json: result
      end
    end
  end

  # POST /wells/:well_id/images/:image_id/point_of_interests
  def create
    @point = @image.point_of_interests.build(point_of_interest_params)

    respond_to do |format|
      if @point.save
        format.json do
          render json: {
            id: @point.id,
            pixel_x: @point.pixel_x,
            pixel_y: @point.pixel_y,
            real_world_x_mm: @point.real_world_x_mm,
            real_world_y_mm: @point.real_world_y_mm,
            real_world_z_mm: @point.real_world_z_mm,
            point_type: @point.point_type,
            description: @point.description,
            marked_at: @point.marked_at,
            display_name: @point.display_name
          }, status: :created
        end
        format.html { redirect_to well_image_path(@well, @image), notice: "Point of interest was successfully created." }
      else
        format.json { render json: @point.errors, status: :unprocessable_entity }
        format.html { redirect_to well_image_path(@well, @image), alert: "Failed to create point of interest." }
      end
    end
  end

  # GET /wells/:well_id/images/:image_id/point_of_interests/:id
  def show
    respond_to do |format|
      format.json do
        render json: {
          id: @point.id,
          pixel_x: @point.pixel_x,
          pixel_y: @point.pixel_y,
          real_world_x_mm: @point.real_world_x_mm,
          real_world_y_mm: @point.real_world_y_mm,
          real_world_z_mm: @point.real_world_z_mm,
          point_type: @point.point_type,
          description: @point.description,
          marked_at: @point.marked_at,
          display_name: @point.display_name
        }
      end
    end
  end

  # PATCH/PUT /wells/:well_id/images/:image_id/point_of_interests/:id
  def update
    respond_to do |format|
      if @point.update(point_of_interest_params)
        format.json do
          render json: {
            id: @point.id,
            pixel_x: @point.pixel_x,
            pixel_y: @point.pixel_y,
            real_world_x_mm: @point.real_world_x_mm,
            real_world_y_mm: @point.real_world_y_mm,
            real_world_z_mm: @point.real_world_z_mm,
            point_type: @point.point_type,
            description: @point.description,
            marked_at: @point.marked_at,
            display_name: @point.display_name
          }
        end
        format.html { redirect_to well_image_path(@well, @image), notice: "Point of interest was successfully updated." }
      else
        format.json { render json: @point.errors, status: :unprocessable_entity }
        format.html { redirect_to well_image_path(@well, @image), alert: "Failed to update point of interest." }
      end
    end
  end

  # DELETE /wells/:well_id/images/:image_id/point_of_interests/:id
  def destroy
    @point.destroy!

    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_to well_image_path(@well, @image), notice: "Point of interest was successfully deleted." }
    end
  end

  # POST /wells/:well_id/images/:image_id/point_of_interests/auto_segment
  def auto_segment
    # Ensure the image file is attached
    unless @image.file.attached?
      render json: { error: "No image file attached" }, status: :unprocessable_entity
      return
    end

    # Call the segmentation service
    result = SegmentationApiService.segment_image(@image.file)

    if result[:error]
      handle_segmentation_error(result[:error])
    else
      handle_segmentation_success(result[:data])
    end
  end

  private

  def handle_segmentation_success(segmentation_data)
    created_points = []

    segmentation_data["segments"].each do |segment|
      centroid = segment["centroid"]

          point = @image.point_of_interests.create!(
            pixel_x: centroid["x"].round,
            pixel_y: centroid["y"].round,
            point_type: Setting.auto_segment_point_type,
            description: "Auto-segmented (confidence: #{segment['confidence'].round(3)})",
            marked_at: Time.current
          )

          created_points << {
        id: point.id,
        pixel_x: point.pixel_x,
        pixel_y: point.pixel_y,
        real_world_x_mm: point.real_world_x_mm,
        real_world_y_mm: point.real_world_y_mm,
        real_world_z_mm: point.real_world_z_mm,
        point_type: point.point_type,
        description: point.description,
        marked_at: point.marked_at,
        display_name: point.display_name
      }
    end

    respond_to do |format|
      format.json do
        render json: {
          message: "Successfully created #{created_points.length} points of interest",
          points: created_points,
          model_used: segmentation_data["model_used"],
          segments_found: segmentation_data["segments"].length
        }
      end
      format.html do
        redirect_to well_image_path(@well, @image),
                   notice: "Successfully auto-segmented image and created #{created_points.length} points of interest"
      end
    end
  end

  def handle_segmentation_error(error_message)
    status = case error_message
    when /timed out/i then :request_timeout
    when /status/i then :service_unavailable
    else :internal_server_error
    end

    respond_to do |format|
      format.json { render json: { error: error_message }, status: status }
      format.html { redirect_to well_image_path(@well, @image), alert: error_message }
    end
  end

  private

  def set_well_and_image
    @well = Well.find(params[:well_id])
    @image = @well.images.find(params[:image_id])
  end

  def set_point_of_interest
    @point = @image.point_of_interests.find(params[:id])
  end

  def point_of_interest_params
    params.require(:point_of_interest).permit(:pixel_x, :pixel_y, :point_type, :description, :marked_at)
  end
end
