module Api::V1
  class LocationsController < BaseController
    before_action :set_location, only: [ :show, :update, :destroy, :current_plates, :history ]

    # GET /api/v1/locations
    def index
      locations = Location.includes(:plates, :plate_locations).all
      render_success(locations.map { |location| location_json(location) })
    end

    # GET /api/v1/locations/carousel
    def carousel
      locations = Location.where.not(carousel_position: nil, hotel_position: nil)
                          .order(:carousel_position, :hotel_position)
                          .includes(:plates, :plate_locations)
      render_success(locations.map { |location| location_json(location) })
    end

    # GET /api/v1/locations/special
    def special
      locations = Location.where(carousel_position: nil, hotel_position: nil)
                          .order(:name)
                          .includes(:plates, :plate_locations)
      render_success(locations.map { |location| location_json(location) })
    end

    # GET /api/v1/locations/grid
    def grid
      grid_data = build_carousel_grid
      formatted_grid = []

      (1..20).each do |hotel|
        row = []
        (1..10).each do |carousel|
          cell_data = grid_data[hotel][carousel]
          row << {
            carousel_position: carousel,
            hotel_position: hotel,
            location: cell_data[:location] ? location_json(cell_data[:location]) : nil,
            plate: cell_data[:plate] ? plate_summary(cell_data[:plate]) : nil,
            occupied: cell_data[:occupied]
          }
        end
        formatted_grid << row
      end

      render_success({
        grid: formatted_grid,
        dimensions: { carousel_positions: 10, hotel_positions: 20 }
      })
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
      if @location.plates.joins(:plate_locations)
                  .where(plate_locations: { id: PlateLocation.select("MAX(id)").group(:plate_id) })
                  .exists?
        render_error("Cannot delete location that currently contains plates", status: :unprocessable_entity)
      else
        @location.destroy!
        render_success(nil, message: "Location deleted successfully")
      end
    end

    # GET /api/v1/locations/:id/current_plates
    def current_plates
      plates = @location.plates.joins(:plate_locations)
                        .where(plate_locations: { id: PlateLocation.select("MAX(id)").group(:plate_id) })
      render_success(plates.map { |plate| plate_summary(plate) })
    end

    # GET /api/v1/locations/:id/history
    def history
      history = @location.plate_locations.recent_first.includes(:plate).limit(50)
      render_success(
        history.map do |plate_location|
          {
            plate: plate_summary(plate_location.plate),
            moved_at: plate_location.moved_at,
            moved_by: plate_location.moved_by
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
        current_plates = location.plates.joins(:plate_locations)
                                .where(plate_locations: { id: PlateLocation.select("MAX(id)").group(:plate_id) })
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

    def build_carousel_grid
      # Same logic as in the main LocationsController
      grid = {}

      (1..20).each do |hotel|
        grid[hotel] = {}
        (1..10).each do |carousel|
          grid[hotel][carousel] = {
            location: nil,
            plate: nil,
            occupied: false
          }
        end
      end

      Location.where.not(carousel_position: nil, hotel_position: nil)
              .includes(plate_locations: :plate)
              .each do |location|
        carousel = location.carousel_position
        hotel = location.hotel_position

        current_plate = location.plates.joins(:plate_locations)
                                .where(plate_locations: { id: PlateLocation.select("MAX(id)").group(:plate_id) })
                                .first

        grid[hotel][carousel] = {
          location: location,
          plate: current_plate,
          occupied: current_plate.present?
        }
      end

      grid
    end
  end
end
