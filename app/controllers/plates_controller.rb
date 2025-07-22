class PlatesController < ApplicationController
  before_action :set_plate, only: %i[ show edit update destroy ]
  before_action :set_deleted_plate, only: %i[ restore permanent_delete ]

  # GET /plates or /plates.json
  def index
    # Handle sorting
    sort_column = params[:sort] || "barcode"
    sort_direction = params[:direction] || "asc"

    # Validate sort parameters
    allowed_columns = %w[barcode created_at]
    sort_column = "barcode" unless allowed_columns.include?(sort_column)
    sort_direction = "asc" unless %w[asc desc].include?(sort_direction)

    case sort_column
    when "barcode"
      @plates = Plate.includes(plate_locations: :location).order("barcode #{sort_direction}")
    when "created_at"
      @plates = Plate.includes(plate_locations: :location).order("created_at #{sort_direction}")
    else
      @plates = Plate.includes(plate_locations: :location).order(:barcode)
    end

    # Add pagination
    @plates = @plates.page(params[:page]).per(25)

    @sort_column = sort_column
    @sort_direction = sort_direction
  end

  # GET /plates/1 or /plates/1.json
  def show
    @wells = @plate.wells.includes(:images, :well_contents)
    @rows = @wells.maximum(:well_row) || 0
    @columns = @wells.maximum(:well_column) || 0

    # Get all points of interest for this plate
    @points_of_interest = PointOfInterest.joins(image: { well: :plate })
                                       .where(plates: { id: @plate.id })
                                       .includes(image: { well: :plate })
                                       .order(:marked_at)
  end

  # GET /plates/new
  def new
    @plate = Plate.new

    # If location_id is provided, pre-populate the location
    if params[:location_id].present?
      @preselected_location = Location.find(params[:location_id])
    end
  end

  # GET /plates/1/edit
  def edit
  end

  # POST /plates or /plates.json
  def create
    @plate = Plate.new(plate_params.except(:location_id))

    # Validate location before saving the plate
    location = find_or_create_location_from_params
    if location
      # Check if location is already occupied before saving the plate
      begin
        # Temporarily validate location occupancy without actually moving the plate
        validate_location_availability(location)
      rescue => e
        Rails.logger.debug "Caught exception in validation: #{e.class}: #{e.message}"

        # Handle ActiveRecord::RecordInvalid specifically
        if e.is_a?(ActiveRecord::RecordInvalid)
          @plate.errors.add(:base, e.record.errors.full_messages.first)
        else
          @plate.errors.add(:base, "Location validation error: #{e.message}")
        end

        # Re-populate form variables for re-rendering
        if params[:location_id].present?
          @preselected_location = Location.find(params[:location_id])
        end

        # Render the form with errors and exit early
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @plate.errors, status: :unprocessable_entity }
        end
        return
      end
    end

    respond_to do |format|
      if @plate.save
        # Handle location assignment (we already validated it's available)
        if location
          begin
            @plate.move_to_location!(location)
          rescue => e
            Rails.logger.error "Error moving plate to location: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            @plate.errors.add(:base, "Error assigning location: #{e.message}")
            # Re-populate form variables for re-rendering
            if params[:location_id].present?
              @preselected_location = Location.find(params[:location_id])
            end
            format.html { render :new, status: :unprocessable_entity }
            format.json { render json: @plate.errors, status: :unprocessable_entity }
            return
          end
        end

        format.html { redirect_to @plate, notice: "Plate was successfully created." }
        format.json { render :show, status: :created, location: @plate }
      else
        # Re-populate form variables for re-rendering
        if params[:location_id].present?
          @preselected_location = Location.find(params[:location_id])
        end
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @plate.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /plates/1 or /plates/1.json
  def update
    respond_to do |format|
      if @plate.update(plate_params.except(:location_id))
        # Handle location assignment
        location = find_or_create_location_from_params
        if location && @plate.current_location&.id != location.id
          begin
            @plate.move_to_location!(location)
          rescue ActiveRecord::RecordInvalid => e
            # Add the location error to the plate and re-render the form
            @plate.errors.add(:base, e.record.errors.full_messages.first)
            # Re-populate form variables for re-rendering
            if params[:location_id].present?
              @preselected_location = Location.find(params[:location_id])
            end
            format.html { render :edit, status: :unprocessable_entity }
            format.json { render json: @plate.errors, status: :unprocessable_entity }
            return
          end
        end

        format.html { redirect_to @plate, notice: "Plate was successfully updated." }
        format.json { render :show, status: :ok, location: @plate }
      else
        # Re-populate form variables for re-rendering
        if params[:location_id].present?
          @preselected_location = Location.find(params[:location_id])
        end
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @plate.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /plates/1 or /plates/1.json
  def destroy
    @plate.destroy!

    respond_to do |format|
      format.html { redirect_to plates_path, status: :see_other, notice: "Plate was successfully deleted." }
      format.json { head :no_content }
    end
  end

  # GET /plates/deleted
  def deleted
    @plates = Plate.only_deleted.includes(plate_locations: :location)
                  .order(:deleted_at)
                  .page(params[:page]).per(25)
  end

  # PATCH /plates/1/restore
  def restore
    @plate.restore!

    respond_to do |format|
      format.html { redirect_to @plate, notice: "Plate was successfully restored." }
      format.json { render :show, status: :ok, location: @plate }
    end
  end

  # DELETE /plates/1/permanent_delete
  def permanent_delete
    @plate.really_destroy!

    respond_to do |format|
      format.html { redirect_to deleted_plates_path, status: :see_other, notice: "Plate was permanently deleted." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_plate
      @plate = Plate.find(params.expect(:id))
    end

    def set_deleted_plate
      @plate = Plate.only_deleted.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def plate_params
      params.require(:plate).permit(:barcode, :name, :location_id, :plate_prototype_id)
        .merge(
          plate_rows: params[:plate_rows],
          plate_columns: params[:plate_columns],
          plate_subwells_per_well: params[:plate_subwells_per_well]
        )
    end

    def find_or_create_location_from_params
      # Check if carousel position parameters are provided
      if params[:carousel_position].present? && params[:hotel_position].present?
        carousel_pos = params[:carousel_position].to_i
        hotel_pos = params[:hotel_position].to_i

        # Find existing carousel location
        Location.find_by(carousel_position: carousel_pos, hotel_position: hotel_pos)
      elsif params[:special_location_id].present?
        # Find the selected special location
        Location.find(params[:special_location_id])
      else
        nil
      end
    end

    def validate_location_availability(location)
      # Check if location is already occupied by another plate
      # Find plates whose most recent location (anywhere) is this location
      latest_locations_subquery = PlateLocation
        .select("plate_id, MAX(id) as latest_id")
        .group(:plate_id)

      occupied_by = PlateLocation.joins(:plate)
                                .joins("INNER JOIN (#{latest_locations_subquery.to_sql}) latest ON plate_locations.plate_id = latest.plate_id AND plate_locations.id = latest.latest_id")
                                .where(location: location)
                                .includes(:plate)
                                .first

      Rails.logger.debug "Checking location availability for location #{location.id} (#{location.display_name})"
      Rails.logger.debug "Found occupied_by: #{occupied_by.inspect}"
      if occupied_by
        Rails.logger.debug "Location is occupied by plate: #{occupied_by.plate.barcode}"
        Rails.logger.debug "About to raise ActiveRecord::RecordInvalid exception"
        # Create a temporary plate-like object to hold the error
        temp_plate = Plate.new
        temp_plate.errors.add(:base, "Location #{location.display_name} is already occupied by plate #{occupied_by.plate.barcode}")
        Rails.logger.debug "Created temp_plate with errors: #{temp_plate.errors.full_messages}"
        raise ActiveRecord::RecordInvalid, temp_plate
      else
        Rails.logger.debug "Location appears to be available"
      end
    end
end
