module Api::V1
  class LocationsController < BaseController
    before_action :set_location, only: [ :show, :update, :destroy, :current_plates, :history ]

    # GET /api/v1/locations
    def index
      locations = Location.includes(:plates, :plate_locations).all

      # Apply search filters
      if params[:name].present?
        locations = locations.where("name LIKE ?", "%#{params[:name]}%")
      end

      if params[:carousel_position].present?
        locations = locations.where(carousel_position: params[:carousel_position])
      end

      if params[:hotel_position].present?
        locations = locations.where(hotel_position: params[:hotel_position])
      end

      # Apply ordering
      locations = locations.order(:name, :carousel_position, :hotel_position)

      render_success(
        locations.map do |location|
          data = location_json(location)
          current_plate = location.current_plates.first
          data[:current_plate_id] = current_plate&.id
          data
        end
      )
    end

    # GET /api/v1/locations/carousel
    def carousel
      locations = Location.where.not(carousel_position: nil, hotel_position: nil)
                          .order(:carousel_position, :hotel_position)
                          .includes(:plates, :plate_locations)
      render_success(
        locations.map do |location|
          data = location_json(location)
          current_plate = location.current_plates.first
          data[:current_plate_id] = current_plate&.id
          data
        end
      )
    end

    # GET /api/v1/locations/special
    def special
      locations = Location.where(carousel_position: nil, hotel_position: nil)
                          .order(:name)
                          .includes(:plates, :plate_locations)
      render_success(
        locations.map do |location|
          data = location_json(location)
          current_plate = location.current_plates.first
          data[:current_plate_id] = current_plate&.id
          data
        end
      )
    end



    # GET /api/v1/locations/:id
    def show
      render_success(location_json(@location, include_details: true))
    end

    # POST /api/v1/locations
    def create
      location = Location.new(processed_location_params)

      if location.save
        render_success(location_json(location, include_details: true), status: :created, message: "Location created successfully")
      else
        render_error("Failed to create location", details: location.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # PUT/PATCH /api/v1/locations/:id
    def update
      if @location.update(processed_location_params)
        render_success(location_json(@location, include_details: true), message: "Location updated successfully")
      else
        render_error("Failed to update location", details: @location.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # DELETE /api/v1/locations/:id
    def destroy
      if @location.current_plates.exists?
        render_error("Cannot delete location that currently contains plates", status: :unprocessable_entity)
      else
        @location.destroy!
        render_success(nil, message: "Location deleted successfully")
      end
    end

    # GET /api/v1/locations/:id/current_plates
    def current_plates
      plates = @location.current_plates
      render_success(plates.map { |plate| plate_summary(plate) })
    end

    # GET /api/v1/locations/:id/history
    def history
      history = @location.plate_locations.recent_first.includes(:plate).limit(50)
      render_success(
        history.map do |plate_location|
          {
            plate: plate_summary(plate_location.plate),
            moved_at: plate_location.moved_at
          }
        end
      )
    end

    private

    def set_location
      @location = Location.find(params[:id])
    end

    def location_params
      params.require(:location).permit(:carousel_position, :hotel_position, :name)
    end

    def processed_location_params
      location_type = params[:location_type] || determine_location_type

      if location_type == "special" || location_params[:carousel_position].blank?
        location_params.except(:carousel_position, :hotel_position)
      else
        location_params.except(:name)
      end
    end

    def determine_location_type
      return "special" if location_params[:name].present?
      return "carousel" if location_params[:carousel_position].present? && location_params[:hotel_position].present?
      "special" # default
    end

    def location_json(location, include_details: false)
      result = {
        id: location.id,
        display_name: location.display_name,
        carousel_position: location.carousel_position,
        hotel_position: location.hotel_position,
        name: location.name,
        created_at: location.created_at,
        updated_at: location.updated_at
      }

      if include_details
        current_plates = location.current_plates
        result[:current_plates] = current_plates.map { |plate| plate_summary(plate) }
        result[:is_occupied] = current_plates.any?
        result[:plates_count] = current_plates.count
      end

      result
    end

    def plate_summary(plate)
      {
        barcode: plate.barcode,
        wells_count: plate.wells.count
      }
    end
  end
end
