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
    @grid_dimensions = get_grid_dimensions
    @carousel_grid = build_carousel_grid

    # Use efficient bulk loading to avoid N+1 queries
    @other_locations = Location.with_current_occupation_data
                               .select { |loc| loc.carousel_position.nil? && loc.hotel_position.nil? }
                               .sort_by { |loc| loc.name || "" }
  end

  # POST /locations/initialise_carousel
  def initialise_carousel
    perform_carousel_initialization
    redirect_to grid_locations_path, notice: "Carousel grid has been initialized successfully."
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
    # Get dynamic dimensions
    dimensions = get_grid_dimensions

    # Return empty grid if no dimensions available
    return {} if dimensions.nil?

    grid = {}
    dimensions[:hotel_range].each do |hotel|
      grid[hotel] = {}
      dimensions[:carousel_range].each do |carousel|
        grid[hotel][carousel] = {
          location: nil,
          plate: nil,
          occupied: false
        }
      end
    end

    # Load all carousel locations with their current plates efficiently
    carousel_locations = Location.with_current_occupation_data
                                .select { |loc| loc.carousel_position.present? && loc.hotel_position.present? }

    carousel_locations.each do |location|
      carousel = location.carousel_position
      hotel = location.hotel_position
      current_plate = location.instance_variable_get(:@cached_current_plate)

      grid[hotel][carousel] = {
        location: location,
        plate: current_plate,
        occupied: current_plate.present?
      }
    end

    grid
  end

  def get_grid_dimensions
    # Get all carousel locations from the database
    locations = Location.where.not(carousel_position: nil, hotel_position: nil)
    carousel_positions = locations.pluck(:carousel_position).compact
    hotel_positions = locations.pluck(:hotel_position).compact

    # Return the dimensions as a hash
    if locations.empty?
      nil
    else
      {
        min_carousel: carousel_positions.min,
        max_carousel: carousel_positions.max,
        min_hotel: hotel_positions.min,
        max_hotel: hotel_positions.max,
        carousel_range: (carousel_positions.min)..(carousel_positions.max),
        hotel_range: (hotel_positions.min)..(hotel_positions.max)
      }
    end
  end

  def perform_carousel_initialization
    (1..10).each do |carousel_pos|
      (1..20).each do |hotel_pos|
        Location.find_or_create_by!(
          carousel_position: carousel_pos,
          hotel_position: hotel_pos
        )
      end
    end
  end
end
