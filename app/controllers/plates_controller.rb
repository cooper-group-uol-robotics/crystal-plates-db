class PlatesController < ApplicationController
  before_action :set_plate, only: %i[ show edit update destroy ]

  # GET /plates or /plates.json
  def index
    @plates = Plate.all
  end

  # GET /plates/1 or /plates/1.json
  def show
    @wells = @plate.wells.with_attached_images
    @rows = @wells.maximum(:well_row) || 0
    @columns = @wells.maximum(:well_column) || 0
  end

  # GET /plates/new
  def new
    @plate = Plate.new
  end

  # GET /plates/1/edit
  def edit
  end

  # POST /plates or /plates.json
  def create
    @plate = Plate.new(plate_params.except(:location_id))

    respond_to do |format|
      if @plate.save
        # Handle location assignment
        location = find_or_create_location_from_params
        if location
          @plate.move_to_location!(location, moved_by: "system")
        end

        format.html { redirect_to @plate, notice: "Plate was successfully created." }
        format.json { render :show, status: :created, location: @plate }
      else
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
          @plate.move_to_location!(location, moved_by: "system")
        end

        format.html { redirect_to @plate, notice: "Plate was successfully updated." }
        format.json { render :show, status: :ok, location: @plate }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @plate.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /plates/1 or /plates/1.json
  def destroy
    @plate.destroy!

    respond_to do |format|
      format.html { redirect_to plates_path, status: :see_other, notice: "Plate was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_plate
      @plate = Plate.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def plate_params
      params.expect(plate: [ :barcode, :location_id ])
    end

    def find_or_create_location_from_params
      # Check if carousel position parameters are provided
      if params[:carousel_position].present? && params[:hotel_position].present?
        carousel_pos = params[:carousel_position].to_i
        hotel_pos = params[:hotel_position].to_i

        # Find existing carousel location
        Location.find_by(carousel_position: carousel_pos, hotel_position: hotel_pos)
      elsif params[:other_location_id].present?
        # Find the selected other location
        Location.find(params[:other_location_id])
      else
        nil
      end
    end
end
