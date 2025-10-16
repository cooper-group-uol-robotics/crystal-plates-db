class PlatesController < ApplicationController
  before_action :set_plate, only: %i[ show edit update destroy bulk_upload_contents ]
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
      @plates = Plate.with_current_location_data.order("barcode #{sort_direction}")
    when "created_at"
      @plates = Plate.with_current_location_data.order("created_at #{sort_direction}")
    else
      @plates = Plate.with_current_location_data.order(:barcode)
    end

    # Add pagination
    @plates = @plates.page(params[:page]).per(25)

    # Cache the current location data to avoid N+1 queries
    Plate.cache_current_location_data(@plates)

    @sort_column = sort_column
    @sort_direction = sort_direction
  end

  # GET /plates/1 or /plates/1.json
  def show
    @wells = @plate.wells.includes(:images, :well_contents, :pxrd_patterns, :scxrd_datasets)
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
        # Handle location assignment/unassignment
        location = find_or_create_location_from_params

        if params[:location_type] == "unassigned"
          # User wants to unassign the plate
          if @plate.current_location.present?
            @plate.unassign_location!
          end
        elsif location && @plate.current_location&.id != location.id
          # User wants to assign to a specific location
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
    @plates = Plate.only_deleted.with_current_location_data.order(:deleted_at).page(params[:page]).per(25)
    # Cache the current location data to avoid N+1 queries
    Plate.cache_current_location_data(@plates)
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

  # POST /plates/:id/bulk_upload_contents
  def bulk_upload_contents
    require "csv"

    unless params[:csv_file].present?
      redirect_to @plate, alert: "Please select a CSV file to upload."
      return
    end

    begin
      csv_content = params[:csv_file].read
      csv = CSV.parse(csv_content, headers: true)

      results = process_bulk_contents_csv(csv)

      if results[:errors].any?
        flash[:alert] = "Upload completed with errors: #{results[:errors].join(', ')}"
      else
        flash[:notice] = "Successfully uploaded #{results[:success_count]} well contents."
      end

    rescue CSV::MalformedCSVError => e
      flash[:alert] = "Invalid CSV file: #{e.message}"
    rescue => e
      flash[:alert] = "Error processing CSV: #{e.message}"
    end

    redirect_to @plate
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
      # Handle unassigned location type
      if params[:location_type] == "unassigned"
        return nil
      end

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
      return if location.nil? # Skip validation for unassigned plates

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

    def process_bulk_contents_csv(csv)
      results = { success_count: 0, errors: [] }

      # Check if we have dual header rows (chemical barcodes and stock solution IDs)
      csv_rows = csv.to_a
      return { success_count: 0, errors: ["CSV file is empty"] } if csv_rows.empty?

      # Detect if we have dual headers by checking the first two rows
      has_dual_headers = detect_dual_headers(csv_rows)
      
      if has_dual_headers
        results.merge!(process_dual_header_csv(csv_rows))
      else
        # Legacy single header processing (stock solutions only)
        results.merge!(process_legacy_csv(csv))
      end

      results
    end

    def detect_dual_headers(csv_rows)
      return false if csv_rows.length < 3 # Need at least 2 header rows + 1 data row

      first_row = csv_rows[0]
      second_row = csv_rows[1]
      
      # Check if first row contains "Chemical Barcode" and second contains "Stock Solution ID"
      first_has_chemical_header = first_row.any? { |cell| cell&.downcase&.include?("chemical") || cell&.downcase&.include?("barcode") }
      second_has_stock_header = second_row.any? { |cell| cell&.downcase&.include?("stock") || cell&.downcase&.include?("solution") }
      
      first_has_chemical_header && second_has_stock_header
    end

    def process_dual_header_csv(csv_rows)
      results = { success_count: 0, errors: [] }
      
      chemical_header_row = csv_rows[0][1..-1] # Skip first column (well labels)
      stock_solution_header_row = csv_rows[1][1..-1] # Skip first column (well labels)
      data_rows = csv_rows[2..-1] # Data starts from third row
      
      # Build content mapping for each column
      content_mapping = {}
      
      chemical_header_row.each_with_index do |barcode, index|
        next if barcode.nil? || barcode.strip.empty?
        
        chemical = Chemical.find_by(barcode: barcode.strip)
        if chemical
          content_mapping[index] = { 
            type: 'Chemical', 
            object: chemical, 
            default_unit: 'mg',
            identifier: barcode.strip 
          }
        else
          results[:errors] << "Chemical not found for barcode: #{barcode}"
        end
      end
      
      stock_solution_header_row.each_with_index do |solution_id, index|
        next if solution_id.nil? || solution_id.strip.empty?
        next if content_mapping[index] # Chemical already mapped to this column
        
        # Try to find stock solution by ID first, then by name
        stock_solution = nil
        if solution_id.match?(/^\d+$/) # If it's just a number, treat as ID
          stock_solution = StockSolution.find_by(id: solution_id.to_i)
        else
          # Try to find by name (case insensitive)
          stock_solution = StockSolution.find_by("name ILIKE ?", solution_id.strip)
        end
        
        if stock_solution
          content_mapping[index] = { 
            type: 'StockSolution', 
            object: stock_solution, 
            default_unit: 'μL',
            identifier: solution_id.strip 
          }
        else
          results[:errors] << "Stock solution not found: #{solution_id}"
        end
      end
      
      return results if content_mapping.empty?
      
      # Process data rows
      data_rows.each do |row|
        well_label = row[0]&.strip
        next if well_label.nil? || well_label.empty? || well_label.downcase.include?("total")

        # Parse well label
        well_row, well_column, subwell = parse_well_label(well_label)
        unless well_row && well_column && subwell
          results[:errors] << "Invalid well label format: #{well_label}"
          next
        end

        # Find the well
        well = @plate.wells.find_by(well_row: well_row, well_column: well_column, subwell: subwell)
        unless well
          results[:errors] << "Well not found: #{well_label} (row: #{well_row}, column: #{well_column}, subwell: #{subwell})"
          next
        end

        # Process each content for this well
        content_mapping.each do |column_index, content_info|
          value_str = row[column_index + 1]&.strip # +1 because we skip first column
          next if value_str.nil? || value_str.empty? || value_str == "0"

          # Add default unit if the value is purely numeric
          if value_str.match?(/^\d+(?:\.\d+)?$/)
            value_str = "#{value_str} #{content_info[:default_unit]}"
          end

          begin
            # Find or create well content using polymorphic association
            well_content = well.well_contents.find_or_initialize_by(contentable: content_info[:object])
            well_content.volume_with_unit = value_str
            well_content.save!

            results[:success_count] += 1
          rescue => e
            results[:errors] << "Error saving #{content_info[:type].downcase} content for well #{well_label}: #{e.message}"
          end
        end
      end
      
      results
    end

    def process_legacy_csv(csv)
      results = { success_count: 0, errors: [] }

      # Get stock solution mapping from headers (skip first column which is well labels)
      headers = csv.headers[1..-1] # Remove first column (well labels)
      stock_solution_mapping = {}

      headers.each do |header|
        next if header.nil? || header.strip.empty? || header.downcase.include?("total")

        # Try to find stock solution by ID first, then by name
        stock_solution = nil
        if header.match?(/^\d+$/) # If header is just a number, treat as ID
          stock_solution = StockSolution.find_by(id: header.to_i)
        else
          # Try to find by name (case insensitive)
          stock_solution = StockSolution.find_by("name ILIKE ?", header.strip)
        end

        if stock_solution
          stock_solution_mapping[header] = stock_solution
        else
          results[:errors] << "Stock solution not found: #{header}"
        end
      end

      return results if stock_solution_mapping.empty?

      csv.each do |row|
        well_label = row[0]&.strip
        next if well_label.nil? || well_label.empty? || well_label.downcase.include?("total")

        # Parse well label (e.g., "A1" -> row: 1, column: 1, subwell: 1; "A1.2" -> row: 1, column: 1, subwell: 2)
        well_row, well_column, subwell = parse_well_label(well_label)
        unless well_row && well_column && subwell
          results[:errors] << "Invalid well label format: #{well_label}"
          next
        end

        # Find the well by row, column, and subwell
        well = @plate.wells.find_by(well_row: well_row, well_column: well_column, subwell: subwell)
        unless well
          results[:errors] << "Well not found: #{well_label} (row: #{well_row}, column: #{well_column}, subwell: #{subwell})"
          next
        end

        # Process each stock solution for this well
        headers.each do |header|
          next unless stock_solution_mapping[header]

          volume_str = row[header]&.strip
          next if volume_str.nil? || volume_str.empty? || volume_str == "0"

          # Add default unit of μL if the value is purely numeric
          if volume_str.match?(/^\d+(?:\.\d+)?$/)
            volume_str = "#{volume_str} μL"
          end

          begin

            stock_solution = stock_solution_mapping[header]

            # Find or create well content using polymorphic association
            well_content = well.well_contents.find_or_initialize_by(contentable: stock_solution)
            well_content.volume_with_unit = volume_str  # Use the virtual attribute that handles parsing
            well_content.save!

            results[:success_count] += 1
          rescue => e
            results[:errors] << "Error saving content for well #{well_label}: #{e.message}"
          end
        end
      end

      results
    end

    def parse_well_label(label)
      # Parse labels like "A1", "B12", "A1.2", "B5-3", "C10_4", etc.
      # First extract the base well (letter + number) and any subwell after delimiter
      match = label.upcase.match(/^([A-Z]+)(\d+)([^A-Z0-9]+(\d+))?$/)
      return nil unless match

      row_letter = match[1]
      column_number = match[2].to_i
      subwell_number = match[4]&.to_i || 1  # Default to subwell 1 if no delimiter found

      # Convert letter to row number (A=1, B=2, etc.)
      # Handle multi-letter combinations like AA, AB, etc.
      row_number = 0
      row_letter.chars.each do |char|
        row_number = row_number * 26 + (char.ord - "A".ord + 1)
      end

      [ row_number, column_number, subwell_number ]
    end
end
