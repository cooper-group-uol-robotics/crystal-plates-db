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

    # Check if there's already a segmentation job queued for this image
    existing_jobs = Solid::Queue::Job.where(
      class_name: "AutoSegmentationJob",
      arguments: [ @image.id, @well.id ].to_json,
      finished_at: nil
    )

    if existing_jobs.exists?
      respond_to do |format|
        format.json do
          render json: {
            status: "queued",
            message: "Segmentation job is already queued or in progress for this image"
          }, status: :accepted
        end
        format.html do
          redirect_to well_image_path(@well, @image),
                     notice: "Segmentation job is already queued or in progress for this image"
        end
      end
      return
    end

    # Queue the segmentation job
    job = AutoSegmentationJob.perform_later(@image.id, @well.id)

    respond_to do |format|
      format.json do
        render json: {
          status: "queued",
          message: "Auto-segmentation job has been queued",
          job_id: job.job_id,
          image_id: @image.id,
          well_id: @well.id
        }, status: :accepted
      end
      format.html do
        redirect_to well_image_path(@well, @image),
                   notice: "Auto-segmentation job has been queued. Results will appear when processing is complete."
      end
    end
  end

  # GET /wells/:well_id/images/:image_id/point_of_interests/auto_segment_status
  def auto_segment_status
    # Check for queued/running jobs
    existing_jobs = Solid::Queue::Job.where(
      class_name: "AutoSegmentationJob",
      arguments: [ @image.id, @well.id ].to_json,
      finished_at: nil
    )

    if existing_jobs.exists?
      job = existing_jobs.first
      render json: {
        status: "processing",
        message: "Segmentation job is #{job.finished_at ? 'completed' : 'in progress'}",
        job_id: job.id,
        queue_position: existing_jobs.where("id < ?", job.id).count + 1
      }
    else
      render json: {
        status: "ready",
        message: "No segmentation job in progress"
      }
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
