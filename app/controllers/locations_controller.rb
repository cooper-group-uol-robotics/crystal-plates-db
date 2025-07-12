class LocationsController < ApplicationController
  before_action :set_location, only: %i[ show edit update destroy ]

  # GET /locations
  def index
    redirect_to grid_locations_path
  end

  # GET /locations/1
  def show
    @current_plates = @location.current_plates
    @location_history = @location.plate_locations.recent_first.includes(:plate).limit(20)
  end

  # GET /locations/new
  def new
    @location = Location.new
  end

  # GET /locations/1/edit
  def edit
  end

  # POST /locations
  def create
    @location = Location.new(location_params_processed)

    respond_to do |format|
      if @location.save
        format.html { redirect_to @location, notice: "Location was successfully created." }
        format.json { render :show, status: :created, location: @location }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /locations/1
  def update
    respond_to do |format|
      if @location.update(location_params_processed)
        format.html { redirect_to @location, notice: "Location was successfully updated." }
        format.json { render :show, status: :ok, location: @location }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /locations/1
  def destroy
    if @location.current_plates.exists?
      redirect_to grid_locations_path, alert: "Cannot delete location that currently contains plates."
    else
      @location.destroy!
      redirect_to grid_locations_path, notice: "Location was successfully deleted."
    end
  end

  # GET /locations/grid
  def grid
    @carousel_grid = build_carousel_grid
    @other_locations = Location.where(carousel_position: nil, hotel_position: nil)
                               .with_current_plate_data
                               .order(:name)
  end

  private

  def set_location
    @location = Location.find(params[:id])
  end

  def location_params
    params.require(:location).permit(:carousel_position, :hotel_position, :name)
  end

  def location_params_processed
    # Check which type of location is being created based on disabled fields
    if params[:location_type] == "special" || location_params[:carousel_position].blank?
      # Special location - clear carousel fields
      location_params.except(:carousel_position, :hotel_position)
    else
      # Carousel location - clear name field
      location_params.except(:name)
    end
  end

  def build_carousel_grid
    # Create a 20x10 grid (hotel 1-20, carousel 1-10)
    # Structure: grid[hotel][carousel] for hotel positions on y-axis, carousel positions on x-axis
    grid = {}

    # Initialize empty grid
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

    # Fill grid with actual location data and current plates
    Location.where.not(carousel_position: nil, hotel_position: nil)
            .with_current_plate_data
            .each do |location|
      carousel = location.carousel_position
      hotel = location.hotel_position

      # Use preloaded current plate
      current_plate = location.current_plates.first

      grid[hotel][carousel] = {
        location: location,
        plate: current_plate,
        occupied: location.has_current_plate?
      }
    end

    grid
  end
end
