module Api::V1
  class PlatesController < BaseController
    before_action :set_plate, only: [ :show, :update, :destroy, :move_to_location, :unassign_location, :location_history, :points_of_interest ]

    # GET /api/v1/plates
    def index
      plates = Plate.includes(:wells, :plate_locations)

      # Filter by assignment status if requested
      if params[:assigned].present?
        if params[:assigned] == "true"
          plates = plates.assigned
        elsif params[:assigned] == "false"
          plates = plates.unassigned
        end
      end

      render_success(plates.all.map { |plate| plate_json(plate, include_wells: false, include_points_of_interest: false) })
    end

    # GET /api/v1/plates/:barcode
    def show
      render_success(plate_json(@plate, include_wells: true, include_points_of_interest: true))
    end

    # POST /api/v1/plates
    def create
      plate = Plate.new(plate_params)

      # Accept plate_prototype_id from params (for API)
      plate.plate_prototype_id = params[:plate_prototype_id] if params[:plate_prototype_id].present?

      if plate.save
        render_success(plate_json(plate, include_wells: true, include_points_of_interest: false), status: :created, message: "Plate created successfully")
      else
        render_error("Failed to create plate", details: plate.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # PUT/PATCH /api/v1/plates/:barcode
    def update
      if @plate.update(plate_params)
        render_success(plate_json(@plate, include_wells: true, include_points_of_interest: false), message: "Plate updated successfully")
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
      location = params[:location_id].present? ? Location.find(params[:location_id]) : nil

      begin
        @plate.move_to_location!(location)

        if location
          render_success(
            {
              plate: plate_json(@plate),
              location: location_json(location),
              message: "Plate #{@plate.barcode} moved to #{location.display_name}"
            },
            message: "Plate moved successfully"
          )
        else
          render_success(
            {
              plate: plate_json(@plate),
              location: nil,
              message: "Plate #{@plate.barcode} unassigned from location"
            },
            message: "Plate unassigned successfully"
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        render_error(e.message, status: :unprocessable_entity)
      end
    end

    # POST /api/v1/plates/:barcode/unassign_location
    def unassign_location
      begin
        @plate.unassign_location!
        render_success(
          {
            plate: plate_json(@plate),
            location: nil,
            message: "Plate #{@plate.barcode} unassigned from location"
          },
          message: "Plate unassigned successfully"
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

    # GET /api/v1/plates/:barcode/points_of_interest
    def points_of_interest
      # Get all points of interest for all wells and images in this plate
      points = PointOfInterest.joins(image: { well: :plate })
                             .where(plates: { id: @plate.id })
                             .includes(image: { well: :plate })
                             .recent

      render_success(points.map { |point| point_json_for_plate(point) })
    end

    private

    def plate_params
      params.require(:plate).permit(:barcode, :name)
    end

    def set_plate
      @plate = Plate.find_by!(barcode: params[:barcode])
    end

    def plate_params
      if params[:plate].present?
        params.require(:plate).permit(:barcode, :name)
      else
        {}
      end
    end

    def plate_json(plate, include_wells: false, include_points_of_interest: false)
      result = {
        barcode: plate.barcode,
        name: plate.name,
        display_name: plate.display_name,
        created_at: plate.created_at,
        updated_at: plate.updated_at,
        rows: plate.rows,
        columns: plate.columns,
        current_location: plate.current_location ? location_json(plate.current_location) : nil
      }
      if include_wells
        # Preload associations for better performance
        wells_with_contents = plate.wells.includes(:well_contents => [:contentable, :unit, :mass_unit])
        
        result[:wells] = wells_with_contents.map do |well|
          {
            id: well.id,
            well_row: well.well_row,
            well_column: well.well_column,
            position: "#{('A'.ord + well.well_row - 1).chr}#{well.well_column}",
            subwell: well.subwell,
            coordinates: well.has_coordinates? ? {
              x_mm: well.x_mm,
              y_mm: well.y_mm,
              z_mm: well.z_mm
            } : nil,
            contents: well.well_contents.map do |content|
              {
                id: content.id,
                type: content.contentable_type.downcase,
                name: content.content_name,
                description: content.content_description,
                volume: content.volume,
                volume_unit: content.unit ? { id: content.unit.id, symbol: content.unit.symbol, name: content.unit.name } : nil,
                mass: content.mass,
                mass_unit: content.mass_unit ? { id: content.mass_unit.id, symbol: content.mass_unit.symbol, name: content.mass_unit.name } : nil,
                display_amount: content.display_amount,
                contentable: content_details(content.contentable)
              }
            end
          }
        end
      else
        result[:wells_count] = plate.wells.count
      end

      if include_points_of_interest
        points = PointOfInterest.joins(image: { well: :plate })
                .where(plates: { id: plate.id })
                .includes(image: { well: :plate })
                .recent
        result[:points_of_interest] = points.map { |point| point_json_for_plate(point) }
      else
        result[:points_of_interest_count] = plate.point_of_interests.count
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

    def point_json_for_plate(point)
      image = point.image
      well = image.well

      # Calculate real-world coordinates using the image's reference and pixel size
      real_x = calculate_real_coordinate(point.pixel_x, image.reference_x_mm, image.pixel_size_x_mm)
      real_y = calculate_real_coordinate(point.pixel_y, image.reference_y_mm, image.pixel_size_y_mm)

      {
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
        updated_at: point.updated_at,
        image: {
          id: image.id,
          filename: image.file.attached? ? image.file.blob.filename.to_s : nil,
          well_id: image.well_id
        },
        well: {
          id: well.id,
          well_row: well.well_row,
          well_column: well.well_column,
          position: "#{('A'.ord + well.well_row - 1).chr}#{well.well_column}"
        }
      }
    end

    def calculate_real_coordinate(pixel_value, reference_mm, pixel_size_mm)
      return nil if reference_mm.nil? || pixel_size_mm.nil?
      reference_mm + (pixel_value * pixel_size_mm)
    end

    def content_details(contentable)
      return nil unless contentable

      case contentable
      when Chemical
        {
          id: contentable.id,
          name: contentable.name,
          sciformation_id: contentable.sciformation_id,
          cas: contentable.cas,
          smiles: contentable.smiles,
          storage: contentable.storage,
          barcode: contentable.barcode,
          amount: contentable.amount
        }
      when StockSolution
        {
          id: contentable.id,
          name: contentable.name,
          display_name: contentable.display_name,
          description: contentable.description,
          components_count: contentable.total_components,
          component_summary: contentable.component_summary
        }
      else
        {
          id: contentable.id,
          name: contentable.respond_to?(:name) ? contentable.name : contentable.to_s
        }
      end
    end
  end
end
