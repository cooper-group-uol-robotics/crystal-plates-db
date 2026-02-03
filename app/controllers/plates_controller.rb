class PlatesController < ApplicationController
  before_action :set_plate, only: %i[ show edit update destroy bulk_upload_contents download_contents_csv bulk_upload_attributes download_attributes_csv ]
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
    @wells = @plate.wells.includes(:images, :pxrd_patterns, :scxrd_datasets, :calorimetry_datasets, 
                                   :chemicals, :stock_solutions, :polymorphic_stock_solutions,
                                   :well_contents, well_scores: :custom_attribute)
    
    # Preload all wells into memory to avoid N+1 queries in the view
    @wells = @wells.to_a
    
    # Pre-group wells by position to avoid expensive selects in the view
    @wells_by_position = @wells.group_by { |w| [w.well_row, w.well_column] }
                         
    # Preload polymorphic associations for well_contents manually 
    # since Rails can't eager load polymorphic associations directly
    ActiveRecord::Associations::Preloader.new(
      records: @wells.flat_map(&:well_contents),
      associations: :contentable
    ).call
    
    # Get custom attributes that have well scores in this plate for layer system
    @plate_custom_attributes = CustomAttribute.with_well_scores_in_plate(@plate)
                                             .select(:id, :name, :description, :data_type)
    
    # Pre-index well scores by well_id and custom_attribute_id for O(1) lookup
    @well_scores_index = {}
    @wells.each do |well|
      @well_scores_index[well.id] = well.well_scores.index_by(&:custom_attribute_id)
    end
    
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

  # GET /plates/builder
  def builder
    @plate = Plate.new
  end

  # POST /plates/create_from_builder
  def create_from_builder
    barcode = params[:barcode]&.strip
    well_data = params[:wells] || {}
    is_existing_plate = params[:is_existing_plate]
    existing_plate_id = params[:existing_plate_id]

    begin
      ActiveRecord::Base.transaction do
        if is_existing_plate && existing_plate_id
          # Update existing plate
          @plate = Plate.find(existing_plate_id)

          # Clear existing chemical well contents for this plate
          @plate.wells.includes(:well_contents).each do |well|
            well.well_contents.where(contentable_type: "Chemical").destroy_all
          end
        else
          # Check if plate with this barcode already exists (for new plates)
          existing_plate = Plate.find_by(barcode: barcode)
          if existing_plate
            render json: {
              success: false,
              error: "Plate with barcode #{barcode} already exists"
            }, status: :unprocessable_entity
            return
          end

          # Create new plate
          @plate = Plate.create!(barcode: barcode)
        end

        # Process well data (same logic for new and existing plates)
        well_data.each do |well_key, well_info|
          next unless well_info["chemical_id"].present? && well_info["mass"].present?

          # Parse well position (e.g., "A1" -> row 1, column 1)
          row_letter = well_key[0]
          column_number = well_key[1..-1].to_i
          row_number = row_letter.ord - "A".ord + 1

          # Find the well
          well = @plate.wells.find_by(well_row: row_number, well_column: column_number, subwell: 1)
          next unless well

          # Find the chemical
          chemical = Chemical.find_by(id: well_info["chemical_id"])
          next unless chemical

          # Mass is now sent in mg from frontend (balance outputs g, converted to mg in JS)
          mass_in_mg = well_info["mass"].to_f

          # Find mg unit
          mg_unit = Unit.find_by(symbol: "mg")

          # Create well content
          well.well_contents.create!(
            contentable: chemical,
            mass: mass_in_mg,
            mass_unit: mg_unit
          )
        end
      end

      action_message = is_existing_plate ? "updated" : "created"
      render json: {
        success: true,
        plate_id: @plate.id,
        redirect_url: plate_path(@plate),
        message: "Plate #{action_message} successfully"
      }
    rescue => e
      action_message = is_existing_plate ? "updating" : "creating"
      render json: {
        success: false,
        error: "Error #{action_message} plate: #{e.message}"
      }, status: :unprocessable_entity
    end
  end

  # GET /plates/check_chemical_cas
  def check_chemical_cas
    chemical_id = params[:chemical_id]

    chemical = Chemical.find_by(id: chemical_id)
    if chemical.nil?
      render json: { found: false, error: "Chemical not found" }
      return
    end

    # Check if this CAS number has been used in any well content
    cas_used = false
    conflicts = []

    if chemical.cas.present?
      # Find all chemicals with the same CAS number
      same_cas_chemicals = Chemical.where(cas: chemical.cas)

      # Find specific well contents that use chemicals with this CAS number
      conflicting_contents = WellContent.joins("JOIN chemicals ON well_contents.contentable_type = 'Chemical' AND well_contents.contentable_id = chemicals.id")
                                      .joins("JOIN wells ON well_contents.well_id = wells.id")
                                      .joins("JOIN plates ON wells.plate_id = plates.id")
                                      .where(chemicals: { cas: chemical.cas })
                                      .includes(:contentable, well: :plate)
                                      .limit(5) # Limit to avoid too much data

      cas_used = conflicting_contents.exists?

      if cas_used
        conflicts = conflicting_contents.map do |content|
          well = content.well
          plate = well.plate
          chemical_used = content.contentable

          {
            plate_barcode: plate.barcode,
            plate_name: plate.name,
            well_position: "#{('A'.ord + well.well_row - 1).chr}#{well.well_column}",
            chemical_name: chemical_used.name,
            chemical_barcode: chemical_used.barcode,
            cas_number: chemical_used.cas
          }
        end
      end
    end

    render json: {
      found: true,
      cas_used: cas_used,
      conflicts: conflicts,
      chemical: {
        id: chemical.id,
        name: chemical.name,
        cas: chemical.cas,
        barcode: chemical.barcode
      }
    }
  end

  # GET /plates/load_for_builder/:barcode
  def load_for_builder
    barcode = params[:barcode]&.strip

    if barcode.blank?
      render json: {
        found: false,
        error: "Barcode is required"
      }, status: :bad_request
      return
    end

    plate = Plate.find_by(barcode: barcode)

    if plate.nil?
      render json: {
        found: false,
        message: "No existing plate found with barcode #{barcode}"
      }
      return
    end

    # Load well data with contents
    wells_data = {}
    plate.wells.includes(well_contents: [ :contentable, :mass_unit ]).each do |well|
      well_position = "#{('A'.ord + well.well_row - 1).chr}#{well.well_column}"

      # Only include wells that have chemical contents
      chemical_content = well.well_contents.find { |wc| wc.chemical? }
      next unless chemical_content

      chemical = chemical_content.contentable
      next unless chemical

      wells_data[well_position] = {
        chemical_id: chemical.id,
        chemical_name: chemical.name,
        chemical_cas: chemical.cas,
        chemical_barcode: chemical.barcode,
        mass: chemical_content.mass ? (chemical_content.mass / 1000.0).to_f : nil # Convert mg back to balance units (g)
      }
    end

    render json: {
      found: true,
      plate: {
        id: plate.id,
        barcode: plate.barcode,
        name: plate.name,
        created_at: plate.created_at
      },
      wells: wells_data,
      message: "Existing plate loaded successfully"
    }
  end

  # POST /plates/save_well_from_builder
  def save_well_from_builder
    barcode = params[:barcode]&.strip
    well_position = params[:well_position]&.strip
    well_data = params[:well_data] || {}

    if barcode.blank? || well_position.blank?
      render json: {
        success: false,
        error: "Barcode and well position are required"
      }, status: :bad_request
      return
    end

    begin
      ActiveRecord::Base.transaction do
        # Find or create the plate
        plate = Plate.find_by(barcode: barcode)
        unless plate
          plate = Plate.create!(barcode: barcode)
        end

        # Parse well position (e.g., "A1" -> row 1, column 1)
        row_letter = well_position[0]
        column_number = well_position[1..-1].to_i
        row_number = row_letter.ord - "A".ord + 1

        # Find the well
        well = plate.wells.find_by(well_row: row_number, well_column: column_number, subwell: 1)
        unless well
          render json: {
            success: false,
            error: "Well #{well_position} not found on plate"
          }, status: :not_found
          return
        end

        # Clear existing chemical contents for this well
        well.well_contents.where(contentable_type: "Chemical").destroy_all

        # Add new content if provided
        if well_data["chemical_id"].present? && well_data["mass"].present?
          # Find the chemical
          chemical = Chemical.find_by(id: well_data["chemical_id"])
          unless chemical
            render json: {
              success: false,
              error: "Chemical not found"
            }, status: :not_found
            return
          end

          # Mass is now sent in mg from frontend (balance outputs g, converted to mg in JS)
          mass_in_mg = well_data["mass"].to_f

          # Find mg unit
          mg_unit = Unit.find_by(symbol: "mg")

          # Create well content
          well.well_contents.create!(
            contentable: chemical,
            mass: mass_in_mg,
            mass_unit: mg_unit
          )
        end
      end

      render json: {
        success: true,
        message: "Well #{well_position} saved successfully"
      }
    rescue => e
      render json: {
        success: false,
        error: "Error saving well: #{e.message}"
      }, status: :unprocessable_entity
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
        # Limit error messages to prevent cookie overflow
        error_count = results[:errors].length
        if error_count > 10
          displayed_errors = results[:errors].first(5)
          flash[:alert] = "Upload completed with #{error_count} errors. First 5 errors: #{displayed_errors.join('; ')}. Please check your CSV file format."
        else
          flash[:alert] = "Upload completed with errors: #{results[:errors].join('; ')}"
        end
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

  # POST /plates/:id/bulk_upload_attributes
  def bulk_upload_attributes
    require "csv"

    unless params[:csv_file].present?
      redirect_to @plate, alert: "Please select a CSV file to upload."
      return
    end

    begin
      csv_content = params[:csv_file].read
      csv = CSV.parse(csv_content, headers: true)

      results = process_bulk_attributes_csv(csv)

      if results[:errors].any?
        # Limit error messages to prevent cookie overflow
        error_count = results[:errors].length
        if error_count > 10
          displayed_errors = results[:errors].first(5)
          flash[:alert] = "Upload completed with #{error_count} errors. First 5 errors: #{displayed_errors.join('; ')}. Please check your CSV file format."
        else
          flash[:alert] = "Upload completed with errors: #{results[:errors].join('; ')}"
        end
      else
        flash[:notice] = "Successfully uploaded #{results[:success_count]} custom attribute values."
      end

    rescue CSV::MalformedCSVError => e
      flash[:alert] = "Invalid CSV file: #{e.message}"
    rescue => e
      flash[:alert] = "Error processing CSV: #{e.message}"
    end

    redirect_to @plate
  end

  # GET /plates/:id/download_attributes_csv
  def download_attributes_csv
    require "csv"

    csv_data = generate_plate_attributes_csv

    filename = "#{@plate.barcode}_attributes_#{Date.current.strftime('%Y%m%d')}.csv"

    respond_to do |format|
      format.csv do
        send_data csv_data, filename: filename, type: "text/csv"
      end
    end
  end

  # GET /plates/:id/download_contents_csv
  def download_contents_csv
    require "csv"

    csv_data = generate_plate_contents_csv(@plate)

    filename = "#{@plate.barcode}_contents_#{Date.current.strftime('%Y%m%d')}.csv"

    respond_to do |format|
      format.csv do
        send_data csv_data, filename: filename, type: "text/csv"
      end
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
      params.require(:plate).permit(:barcode, :name, :location_id, :plate_prototype_id, :coshh_form_code)
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

      # Process dual header CSV format only
      csv_rows = csv.to_a
      return { success_count: 0, errors: [ "CSV file is empty" ] } if csv_rows.empty?

      # Validate that we have dual headers
      unless detect_dual_headers(csv_rows)
        results[:errors] << "Invalid CSV format. Please use the dual header format with 'Chemical Barcode' in the first row and 'Stock Solution ID' in the second row."
        return results
      end

      results.merge!(process_dual_header_csv(csv_rows))
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
            type: "Chemical",
            object: chemical,
            default_unit: "mg",
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
            type: "StockSolution",
            object: stock_solution,
            default_unit: "μL",
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

          # Find or create well content using polymorphic association
          well_content = well.well_contents.find_or_initialize_by(contentable: content_info[:object])
          well_content.volume_with_unit = value_str
          
          if well_content.save
            results[:success_count] += 1
          else
            error_msg = well_content.errors.full_messages.join(', ')
            results[:errors] << "Well #{well_label} (#{content_info[:identifier]}): #{error_msg}"
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

    def generate_plate_contents_csv(plate)
      require "csv"

      # Get all wells with their contents
      wells = plate.wells.includes(well_contents: [ :contentable, :unit, :mass_unit ]).order(:well_row, :well_column, :subwell)

      # Collect all chemicals and stock solutions used across the plate
      chemicals = Set.new
      stock_solutions = Set.new

      wells.each do |well|
        well.well_contents.each do |content|
          if content.chemical? && content.contentable.present?
            chemicals.add(content.contentable)
          end
          if content.stock_solution? && content.contentable.present?
            stock_solutions.add(content.contentable)
          end
        end
      end

      chemicals = chemicals.to_a.compact.sort_by { |c| c.barcode || "" }
      stock_solutions = stock_solutions.to_a.compact.sort_by { |s| s.id || 0 }

      CSV.generate do |csv|
        # Always use dual header format with labels
        # First header row: Chemical barcodes with label
        chemical_header = [ "Chemical Barcode" ] + chemicals.map { |c| c.barcode || "UNKNOWN" } + Array.new(stock_solutions.length, "")
        csv << chemical_header

        # Second header row: Stock solution IDs with label
        stock_solution_header = [ "Stock Solution ID" ] + Array.new(chemicals.length, "") + stock_solutions.map { |s| s.id || "UNKNOWN" }
        csv << stock_solution_header

        # Data rows
        wells.each do |well|
          well_label = well.subwell == 1 ? well.well_label : "#{well.well_label}.#{well.subwell}"
          row_data = [ well_label ]

          # Add chemical amounts (in mg)
          chemicals.each do |chemical|
            content = well.well_contents.find { |wc| wc.contentable == chemical }
            if content&.has_mass?
              # Convert to mg if needed
              amount = content.mass
              unit_symbol = content.mass_unit&.symbol&.downcase

              case unit_symbol
              when "g"
                amount *= 1000 # g to mg
              when "kg"
                amount *= 1_000_000 # kg to mg
                # mg is default, no conversion needed
              end

              row_data << amount.to_s
            else
              row_data << ""
            end
          end

          # Add stock solution volumes (in µL)
          stock_solutions.each do |stock_solution|
            content = well.well_contents.find { |wc| wc.contentable == stock_solution }
            if content&.has_volume?
              # Convert to µL if needed
              amount = content.volume
              unit_symbol = content.unit&.symbol&.downcase

              case unit_symbol
              when "ml", "mL"
                amount *= 1000 # mL to µL
              when "l"
                amount *= 1_000_000 # L to µL
              when "nl"
                amount /= 1000 # nL to µL
                # µL is default, no conversion needed
              end

              row_data << amount.to_s
            else
              row_data << ""
            end
          end

          csv << row_data
        end
      end
    end

    def process_bulk_attributes_csv(csv)
      results = { success_count: 0, errors: [] }

      return { success_count: 0, errors: [ "CSV file is empty" ] } if csv.empty?

      # Get headers - CSV is already parsed with headers
      headers = csv.headers.compact
      well_column = headers.first # First column should be well labels
      attribute_columns = headers[1..-1] # Rest are attribute names

      if well_column.nil? || attribute_columns.empty?
        results[:errors] << "CSV must have well labels in first column and at least one attribute column"
        return results
      end

      # Validate that all attribute columns exist as custom attributes
      existing_attributes = CustomAttribute.where(name: attribute_columns).index_by(&:name)
      missing_attributes = attribute_columns.reject { |name| existing_attributes.key?(name) }

      if missing_attributes.any?
        results[:errors] << "Unknown custom attributes: #{missing_attributes.join(', ')}. Available attributes: #{CustomAttribute.pluck(:name).join(', ')}"
        return results
      end

      # Process each data row
      csv.each do |row|
        well_label = row[well_column]&.strip
        next if well_label.nil? || well_label.empty?

        # Parse well label
        well_row, well_column_num, subwell = parse_well_label(well_label)
        unless well_row && well_column_num && subwell
          results[:errors] << "Invalid well label format: #{well_label}"
          next
        end

        # Find the well
        well = @plate.wells.find_by(well_row: well_row, well_column: well_column_num, subwell: subwell)
        unless well
          results[:errors] << "Well not found: #{well_label}"
          next
        end

        # Process each attribute value
        attribute_columns.each do |attr_name|
          value = row[attr_name]
          next if value.nil? || value.strip.empty?

          # Validate numeric value
          numeric_value = Float(value.strip) rescue nil
          if numeric_value.nil?
            results[:errors] << "Invalid numeric value '#{value}' for attribute '#{attr_name}' in well #{well_label}"
            next
          end

          # Find or create well score
          custom_attribute = existing_attributes[attr_name]
          well_score = WellScore.find_or_initialize_by(
            well: well,
            custom_attribute: custom_attribute
          )
          
          well_score.set_display_value(numeric_value)
          
          if well_score.save
            results[:success_count] += 1 if well_score.saved_changes?
          else
            results[:errors] << "Failed to save #{attr_name} for well #{well_label}: #{well_score.errors.full_messages.join(', ')}"
          end
        end
      end

      results
    end

    def generate_plate_attributes_csv
      require "csv"

      # Get all wells ordered by position
      wells = @plate.wells.includes(:well_scores, well_scores: :custom_attribute).order(:well_row, :well_column, :subwell)

      # Get all custom attributes that have scores on this plate
      attribute_names = CustomAttribute.joins(:well_scores)
                                      .where(well_scores: { well_id: wells.pluck(:id) })
                                      .distinct
                                      .order(:name)
                                      .pluck(:name)

      # If no attributes have been set, include all available attributes
      if attribute_names.empty?
        attribute_names = CustomAttribute.order(:name).pluck(:name)
      end

      CSV.generate do |csv|
        # Header row: Well, then all attribute names
        headers = ["Well"] + attribute_names
        csv << headers

        # Data rows: one per well
        wells.each do |well|
          well_label = well.subwell == 1 ? well.well_label : "#{well.well_label}.#{well.subwell}"
          row_data = [well_label]

          # Add value for each attribute (or empty string if not set)
          attribute_names.each do |attr_name|
            well_score = well.well_scores.find { |ws| ws.custom_attribute.name == attr_name }
            row_data << (well_score&.display_value&.to_s || "")
          end

          csv << row_data
        end
      end
    end
end
