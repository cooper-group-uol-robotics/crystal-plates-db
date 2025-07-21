module Api::V1
  class PointsOfInterestController < BaseController
    before_action :set_well_and_image, only: [ :index, :create ]
    before_action :set_point_of_interest, only: [ :show, :update, :destroy ]

    # GET /api/v1/wells/:well_id/images/:image_id/points_of_interest
    # GET /api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest
    def index
      @points = @image.point_of_interests.recent
      render_success(@points.map { |point| point_json(point) })
    end

    # GET /api/v1/points_of_interest (standalone)
    def index_standalone
      points = PointOfInterest.recent.includes(:image)
      render_success(points.map { |point| point_json(point, include_context: true) })
    end

    # GET /api/v1/points_of_interest/by_type
    def by_type
      point_type = params[:type]
      points = PointOfInterest.where(point_type: point_type).recent.includes(:image)
      render_success(points.map { |point| point_json(point, include_context: true) })
    end

    # GET /api/v1/points_of_interest/recent
    def recent
      limit = params[:limit]&.to_i || 50
      points = PointOfInterest.recent.limit(limit).includes(:image)
      render_success(points.map { |point| point_json(point, include_context: true) })
    end

    # GET /api/v1/points_of_interest/crystals
    def crystals
      points = PointOfInterest.where(point_type: "crystal").recent.includes(:image)
      render_success(points.map { |point| point_json(point, include_context: true) })
    end

    # GET /api/v1/points_of_interest/particles
    def particles
      points = PointOfInterest.where(point_type: "particle").recent.includes(:image)
      render_success(points.map { |point| point_json(point, include_context: true) })
    end

    # POST /api/v1/wells/:well_id/images/:image_id/points_of_interest
    # POST /api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest
    def create
      @point = @image.point_of_interests.build(point_of_interest_params)

      if @point.save
        render_success(point_json(@point), status: :created, message: "Point of interest created successfully")
      else
        render_error("Failed to create point of interest", details: @point.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # GET /api/v1/wells/:well_id/images/:image_id/points_of_interest/:id
    # GET /api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest/:id
    def show
      render_success(point_json(@point))
    end

    # PUT/PATCH /api/v1/wells/:well_id/images/:image_id/points_of_interest/:id
    # PUT/PATCH /api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest/:id
    def update
      if @point.update(point_of_interest_params)
        render_success(point_json(@point), message: "Point of interest updated successfully")
      else
        render_error("Failed to update point of interest", details: @point.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # DELETE /api/v1/wells/:well_id/images/:image_id/points_of_interest/:id
    # DELETE /api/v1/plates/:barcode/wells/:well_id/images/:image_id/points_of_interest/:id
    def destroy
      @point.destroy!
      render_success(nil, message: "Point of interest deleted successfully")
    end

    private

    def set_well_and_image
      if params[:barcode]
        # Nested under plates
        @plate = Plate.find_by!(barcode: params[:barcode])
        @well = @plate.wells.find(params[:well_id])
      else
        # Direct well access
        @well = Well.find(params[:well_id])
      end
      @image = @well.images.find(params[:image_id])
    end

    def set_point_of_interest
      if params[:well_id] && params[:image_id]
        # Nested route - find via image
        set_well_and_image
        @point = @image.point_of_interests.find(params[:id])
      else
        # Standalone route - find directly
        @point = PointOfInterest.find(params[:id])
        @image = @point.image
        @well = @image.well
      end
    end

    def point_of_interest_params
      params.require(:point_of_interest).permit(:pixel_x, :pixel_y, :point_type, :description, :marked_at)
    end

    def point_json(point, include_context: false)
      # Calculate real-world coordinates using the image's reference and pixel size
      image = point.image
      real_x = calculate_real_coordinate(point.pixel_x, image.reference_x_mm, image.pixel_size_x_mm)
      real_y = calculate_real_coordinate(point.pixel_y, image.reference_y_mm, image.pixel_size_y_mm)

      result = {
        id: point.id,
        pixel_x: point.pixel_x,
        pixel_y: point.pixel_y,
        real_world_x_mm: real_x,
        real_world_y_mm: real_y,
        real_world_z_mm: image.reference_z_mm,
        point_type: point.point_type,
        description: point.description,
        marked_at: point.marked_at,
        display_name: point.display_name,
        created_at: point.created_at,
        updated_at: point.updated_at
      }

      if include_context
        result[:image] = {
          id: image.id,
          filename: image.filename,
          well_id: image.well_id
        }
        result[:well] = {
          id: image.well_id,
          plate_barcode: image.well.plate.barcode
        }
      end

      result
    end

    def calculate_real_coordinate(pixel_value, reference_mm, pixel_size_mm)
      return nil if reference_mm.nil? || pixel_size_mm.nil?
      reference_mm + (pixel_value * pixel_size_mm)
    end
  end
end
