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

    # Validate API configuration
    unless Setting.get("segmentation_api_endpoint").present?
      render json: {
        error: "Segmentation API endpoint not configured",
        message: "Please configure the segmentation API endpoint in settings"
      }, status: :service_unavailable
      return
    end

    # With Async adapter, jobs process immediately so no duplicate checking needed
    Rails.logger.info "Queueing auto-segmentation job for image #{@image.id} using #{Rails.application.config.active_job.queue_adapter} adapter"

    # Queue the segmentation job for background processing
    begin
      job = AutoSegmentationJob.perform_later(@image.id, @well.id)

      render json: {
        status: "queued",
        message: "Auto-segmentation job has been queued for processing",
        job_id: job.job_id,
        image_id: @image.id,
        well_id: @well.id,
        estimated_completion: "Processing typically takes 30-60 seconds"
      }, status: :accepted
    rescue => e
      Rails.logger.error "Failed to queue auto-segmentation job: #{e.message}"
      render json: {
        status: "error",
        message: "Failed to queue auto-segmentation job",
        error: e.message,
        image_id: @image.id,
        well_id: @well.id
      }, status: :internal_server_error
    end
  end

  # GET /wells/:well_id/images/:image_id/point_of_interests/auto_segment_status
  def auto_segment_status
    begin
      # Simple status check based on recent point creation
      # With Async adapter, jobs process immediately so we check for results
      recent_auto_points = @image.point_of_interests
        .where("created_at >= ?", 5.minutes.ago)
        .where("description LIKE ?", "%Auto-segmented%")

      if recent_auto_points.any?
        # Found recent auto-segmented points - job completed successfully
        render json: {
          status: "completed",
          message: "Auto-segmentation completed successfully",
          points_created: recent_auto_points.count,
          last_point_created: recent_auto_points.maximum(:created_at),
          image_id: @image.id,
          well_id: @well.id,
          adapter: Rails.application.config.active_job.queue_adapter.to_s
        }
      else
        # No recent auto-segmented points - either idle or job failed
        render json: {
          status: "idle",
          message: "No recent auto-segmentation activity detected",
          image_id: @image.id,
          well_id: @well.id,
          adapter: Rails.application.config.active_job.queue_adapter.to_s
        }
      end

    rescue => e
      Rails.logger.error "Error checking auto-segmentation status: #{e.message}"
      render json: {
        status: "error",
        message: "Unable to check job status",
        error: e.message
      }, status: :internal_server_error
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
