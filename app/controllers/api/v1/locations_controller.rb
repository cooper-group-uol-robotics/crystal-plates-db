module Api::V1
  class LocationsController < BaseController
    before_action :set_location, only: [ :show, :update, :destroy, :current_plates, :history, :unassign_all_plates ]

    # GET /api/v1/locations
    def index
      # Use efficient bulk loading to avoid N+1 queries
      locations = Location.with_current_occupation_data

      # Apply search filters
      if params[:name].present?
        locations = locations.select { |loc| loc.name&.downcase&.include?(params[:name].downcase) }
      end

      if params[:carousel_position].present?
        locations = locations.select { |loc| loc.carousel_position == params[:carousel_position].to_i }
      end

      if params[:hotel_position].present?
        locations = locations.select { |loc| loc.hotel_position == params[:hotel_position].to_i }
      end

      # Apply ordering
      locations = locations.sort_by { |loc| [ loc.name || "", loc.carousel_position || 0, loc.hotel_position || 0 ] }

      render_success(
        locations.map do |location|
          data = location_json(location)
          # Use cached current plate data to avoid additional queries
          cached_plate = location.instance_variable_get(:@cached_current_plate)
          data[:current_plate_barcode] = cached_plate&.barcode
          data
        end
      )
    end

    # GET /api/v1/locations/carousel
    def carousel
      # Use efficient bulk loading to avoid N+1 queries
      locations = Location.with_current_occupation_data
                          .select { |loc| loc.carousel_position.present? && loc.hotel_position.present? }
                          .sort_by { |loc| [ loc.carousel_position, loc.hotel_position ] }

      render_success(
        locations.map do |location|
          data = location_json(location)
          # Use cached current plate data to avoid additional queries
          cached_plate = location.instance_variable_get(:@cached_current_plate)
          data[:current_plate_barcode] = cached_plate&.barcode
          data
        end
      )
    end

    # GET /api/v1/locations/special
    def special
      # Use efficient bulk loading to avoid N+1 queries
      locations = Location.with_current_occupation_data
                          .select { |loc| loc.carousel_position.nil? && loc.hotel_position.nil? }
                          .sort_by { |loc| loc.name || "" }

      render_success(
        locations.map do |location|
          data = location_json(location)
          # Use cached current plate data to avoid additional queries
          cached_plate = location.instance_variable_get(:@cached_current_plate)
          data[:current_plate_barcode] = cached_plate&.barcode
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

    # POST /api/v1/locations/:id/unassign_all_plates
    def unassign_all_plates
      current_plates = @location.current_plates
      
      if current_plates.empty?
        render_success(
          {
            location: location_json(@location),
            plates_unassigned: [],
            message: "No plates found at location #{@location.display_name}"
          },
          message: "No plates to unassign"
        )
        return
      end

      unassigned_plates = []
      errors = []

      current_plates.each do |plate|
        begin
          plate.unassign_location!
          unassigned_plates << {
            barcode: plate.barcode,
            status: "success"
          }
        rescue ActiveRecord::RecordInvalid => e
          errors << {
            barcode: plate.barcode,
            error: e.message,
            status: "error"
          }
        end
      end

      if errors.empty?
        render_success(
          {
            location: location_json(@location),
            plates_unassigned: unassigned_plates,
            message: "Successfully unassigned #{unassigned_plates.count} plates from location #{@location.display_name}"
          },
          message: "All plates unassigned successfully"
        )
      else
        render_error(
          {
            location: location_json(@location),
            plates_unassigned: unassigned_plates,
            errors: errors,
            message: "#{unassigned_plates.count} plates unassigned successfully, #{errors.count} failed"
          },
          message: "Some plates failed to unassign",
          status: :unprocessable_entity
        )
      end
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
        # Use cached current plate data if available, otherwise fall back to query
        if location.instance_variable_defined?(:@cached_current_plate)
          cached_plate = location.instance_variable_get(:@cached_current_plate)
          current_plates = cached_plate ? [ cached_plate ] : []
        else
          current_plates = location.current_plates
        end

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
