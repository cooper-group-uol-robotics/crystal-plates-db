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
          # Calculate real-world coordinates using the image's reference and pixel size
          real_x = !@image.reference_x_mm.nil? && !@image.pixel_size_x_mm.nil? ?
                   @image.reference_x_mm + (point.pixel_x * @image.pixel_size_x_mm) : nil
          real_y = !@image.reference_y_mm.nil? && !@image.pixel_size_y_mm.nil? ?
                   @image.reference_y_mm + (point.pixel_y * @image.pixel_size_y_mm) : nil

          {
            id: point.id,
            pixel_x: point.pixel_x,
            pixel_y: point.pixel_y,
            real_world_x_mm: real_x,
            real_world_y_mm: real_y,
            real_world_z_mm: @image.reference_z_mm,
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
          # Calculate coordinates the same way as in index
          real_x = !@image.reference_x_mm.nil? && !@image.pixel_size_x_mm.nil? ?
                   @image.reference_x_mm + (@point.pixel_x * @image.pixel_size_x_mm) : nil
          real_y = !@image.reference_y_mm.nil? && !@image.pixel_size_y_mm.nil? ?
                   @image.reference_y_mm + (@point.pixel_y * @image.pixel_size_y_mm) : nil

          render json: {
            id: @point.id,
            pixel_x: @point.pixel_x,
            pixel_y: @point.pixel_y,
            real_world_x_mm: real_x,
            real_world_y_mm: real_y,
            real_world_z_mm: @image.reference_z_mm,
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
        # Calculate coordinates the same way as in index
        real_x = !@image.reference_x_mm.nil? && !@image.pixel_size_x_mm.nil? ?
                 @image.reference_x_mm + (@point.pixel_x * @image.pixel_size_x_mm) : nil
        real_y = !@image.reference_y_mm.nil? && !@image.pixel_size_y_mm.nil? ?
                 @image.reference_y_mm + (@point.pixel_y * @image.pixel_size_y_mm) : nil

        render json: {
          id: @point.id,
          pixel_x: @point.pixel_x,
          pixel_y: @point.pixel_y,
          real_world_x_mm: real_x,
          real_world_y_mm: real_y,
          real_world_z_mm: @image.reference_z_mm,
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
          # Calculate coordinates the same way as in index
          real_x = !@image.reference_x_mm.nil? && !@image.pixel_size_x_mm.nil? ?
                   @image.reference_x_mm + (@point.pixel_x * @image.pixel_size_x_mm) : nil
          real_y = !@image.reference_y_mm.nil? && !@image.pixel_size_y_mm.nil? ?
                   @image.reference_y_mm + (@point.pixel_y * @image.pixel_size_y_mm) : nil

          render json: {
            id: @point.id,
            pixel_x: @point.pixel_x,
            pixel_y: @point.pixel_y,
            real_world_x_mm: real_x,
            real_world_y_mm: real_y,
            real_world_z_mm: @image.reference_z_mm,
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
