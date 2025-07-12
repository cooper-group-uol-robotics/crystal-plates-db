module Api::V1
  class PlatesController < BaseController
    before_action :set_plate, only: [ :show, :update, :destroy, :move_to_location, :location_history ]

    # GET /api/v1/plates
    def index
      plates = Plate.includes(:wells, :plate_locations).all
      render_success(plates.map { |plate| plate_json(plate) })
    end

    # GET /api/v1/plates/:barcode
    def show
      render_success(plate_json(@plate, include_wells: true))
    end

    # POST /api/v1/plates
    def create
      plate = Plate.new(plate_params)

      if plate.save
        render_success(plate_json(plate, include_wells: true), status: :created, message: "Plate created successfully")
      else
        render_error("Failed to create plate", details: plate.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # PUT/PATCH /api/v1/plates/:barcode
    def update
      if @plate.update(plate_params)
        render_success(plate_json(@plate, include_wells: true), message: "Plate updated successfully")
      else
        render_error("Failed to update plate", details: @plate.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # DELETE /api/v1/plates/:barcode
    def destroy
      if @plate.destroy
        render_success(nil, message: "Plate deleted successfully")
      else
        render_error("Failed to delete plate", details: @plate.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # POST /api/v1/plates/:barcode/move_to_location
    def move_to_location
      location = Location.find(params[:location_id])

      begin
        @plate.move_to_location!(location)
        render_success(
          {
            plate: plate_json(@plate),
            location: location_json(location),
            message: "Plate #{@plate.barcode} moved to #{location.display_name}"
          },
          message: "Plate moved successfully"
        )
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message, status: :unprocessable_entity)
      end
    end

    # GET /api/v1/plates/:barcode/location_history
    def location_history
      history = @plate.location_history.includes(:location).limit(50)
      render_success(
        history.map do |plate_location|
          {
            location: location_json(plate_location.location),
            moved_at: plate_location.moved_at
          }
        end
      )
    end

    private

    def set_plate
      @plate = Plate.find_by!(barcode: params[:barcode])
    end

    def plate_params
      params.require(:plate).permit(:barcode)
    end

    def plate_json(plate, include_wells: false)
      result = {
        barcode: plate.barcode,
        created_at: plate.created_at,
        updated_at: plate.updated_at,
        rows: plate.rows,
        columns: plate.columns,
        current_location: plate.current_location ? location_json(plate.current_location) : nil
      }

      if include_wells
        result[:wells] = plate.wells.map do |well|
          {
            id: well.id,
            well_row: well.well_row,
            well_column: well.well_column,
            position: "#{('A'.ord + well.well_row - 1).chr}#{well.well_column}"
          }
        end
      else
        result[:wells_count] = plate.wells.count
      end

      result
    end

    def location_json(location)
      {
        id: location.id,
        display_name: location.display_name,
        carousel_position: location.carousel_position,
        hotel_position: location.hotel_position,
        name: location.name
      }
    end
  end
end
