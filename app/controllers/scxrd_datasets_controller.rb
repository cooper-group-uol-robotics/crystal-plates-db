class ScxrdDatasetsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  before_action :log_request
  before_action :set_well, if: -> { params[:well_id].present? && params[:well_id] != "null" }
  before_action :set_scxrd_dataset, only: [ :show, :edit, :update, :destroy, :download, :download_peak_table, :crystal_image, :structure_file, :image_data, :peak_table_data ]

  def index
    if params[:well_id].present?
      # Well-specific index (existing functionality)
      @scxrd_datasets = @well.scxrd_datasets.order(created_at: :desc)
      render partial: "scxrd_datasets/gallery", locals: { well: @well }
    else
      # Global index for all SCXRD datasets
      @scxrd_datasets = ScxrdDataset.includes(well: :plate)

      # Apply search functionality
      if params[:search].present?
        search_term = params[:search].strip
        @scxrd_datasets = @scxrd_datasets.where(
          "LOWER(experiment_name) LIKE ?",
          "%#{search_term.downcase}%"
        )
      end

      # Apply sorting
      case params[:sort]
      when "measured_at"
        direction = params[:direction] == "asc" ? :asc : :desc
        @scxrd_datasets = @scxrd_datasets.order(measured_at: direction)
      when "experiment_name"
        direction = params[:direction] == "asc" ? :asc : :desc
        @scxrd_datasets = @scxrd_datasets.order(experiment_name: direction)
      else
        # Default sort by created_at
        direction = params[:direction] == "asc" ? :asc : :desc
        @scxrd_datasets = @scxrd_datasets.order(created_at: direction)
      end

      @scxrd_datasets = @scxrd_datasets.page(params[:page]).per(10)

      respond_to do |format|
        format.html { render "index" }
        format.json do
          render json: {
            success: true,
            scxrd_datasets: @scxrd_datasets.map do |dataset|
              {
                id: dataset.id,
                experiment_name: dataset.experiment_name,
                measured_at: dataset.measured_at&.strftime("%Y-%m-%d %H:%M:%S"),
                lattice_centring: "primitive",
                has_peak_table: dataset.has_peak_table?,
                total_diffraction_images: dataset.diffraction_images.count,
                well_id: dataset.well&.id,
                well_location: dataset.well&.location_code,
                plate_id: dataset.well&.plate&.id,
                plate_name: dataset.well&.plate&.plate_id
              }
            end,
            total_count: @scxrd_datasets.total_count,
            current_page: @scxrd_datasets.current_page,
            total_pages: @scxrd_datasets.total_pages
          }
        end
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @scxrd_dataset.id,
          experiment_name: @scxrd_dataset.experiment_name,
          measured_at: @scxrd_dataset.measured_at&.strftime("%Y-%m-%d %H:%M:%S"),
          lattice_centring: "primitive",  # Primitive cells are always primitive
          has_peak_table: @scxrd_dataset.has_peak_table?,

          has_diffraction_images: @scxrd_dataset.has_diffraction_images?,
          diffraction_images_count: @scxrd_dataset.diffraction_images_count,
          has_archive: @scxrd_dataset.archive.attached?,
          has_crystal_image: @scxrd_dataset.has_crystal_image?,
          peak_table_size: @scxrd_dataset.has_peak_table? ? number_to_human_size(@scxrd_dataset.peak_table_size) : nil,

          primitive_unit_cell: @scxrd_dataset.primitive_a.present? ? {
            a: number_with_precision(@scxrd_dataset.primitive_a, precision: 3),
            b: number_with_precision(@scxrd_dataset.primitive_b, precision: 3),
            c: number_with_precision(@scxrd_dataset.primitive_c, precision: 3),
            alpha: number_with_precision(@scxrd_dataset.primitive_alpha, precision: 1),
            beta: number_with_precision(@scxrd_dataset.primitive_beta, precision: 1),
            gamma: number_with_precision(@scxrd_dataset.primitive_gamma, precision: 1)
          } : nil,
          real_world_coordinates: (@scxrd_dataset.real_world_x_mm || @scxrd_dataset.real_world_y_mm || @scxrd_dataset.real_world_z_mm) ? {
            x_mm: @scxrd_dataset.real_world_x_mm,
            y_mm: @scxrd_dataset.real_world_y_mm,
            z_mm: @scxrd_dataset.real_world_z_mm
          } : nil
        }
      end
    end
  end

  def new
    if @well
      @scxrd_dataset = @well.scxrd_datasets.build
    else
      @scxrd_dataset = ScxrdDataset.new
    end
    # Note: Lattice centrings removed - primitive cells are always primitive
  end

  def create
    # Extract compressed archive parameter before processing model params
    compressed_archive = params.dig(:scxrd_dataset, :compressed_archive)

    if @well
      @scxrd_dataset = @well.scxrd_datasets.build(scxrd_dataset_params)
      success_redirect = [ @well, @scxrd_dataset ]
    else
      @scxrd_dataset = ScxrdDataset.new(scxrd_dataset_params)
      success_redirect = @scxrd_dataset
    end

    # Set default measurement datetime if not provided (will be overridden by datacoll.ini if available)
    @scxrd_dataset.measured_at = Time.current if @scxrd_dataset.measured_at.blank?

    # Validate compressed archive is present
    unless compressed_archive.present?
      @scxrd_dataset.errors.add(:base, "Experiment folder is required")
      render :new
      return
    end

    # Save the dataset first to get an ID, then process the archive
    if @scxrd_dataset.save
      begin
        # Store the uploaded archive first
        @scxrd_dataset.archive.attach(compressed_archive)
        @scxrd_dataset.save!

        Rails.logger.info "SCXRD: Queueing processing job for dataset #{@scxrd_dataset.id}"

        # Queue background processing (same as API)
        ScxrdArchiveProcessingJob.perform_later(@scxrd_dataset.id)

        redirect_to success_redirect, notice: "SCXRD dataset was successfully created and is being processed."
      rescue => e
        Rails.logger.error "SCXRD: Failed to queue processing: #{e.message}"
        @scxrd_dataset.errors.add(:base, "Failed to queue processing: #{e.message}")
        render :new
      end
    else
      Rails.logger.error "SCXRD: Failed to save dataset. Errors: #{@scxrd_dataset.errors.full_messages.join(', ')}"
      # Note: Lattice centrings removed - primitive cells are always primitive
      render :new
    end
  end

  def edit
    # Note: Lattice centrings removed - primitive cells are always primitive
  end

  def update
    # Process uploaded compressed archive if provided
    if params[:scxrd_dataset][:compressed_archive].present?
      Rails.logger.info "SCXRD: Queueing reprocessing job for dataset #{@scxrd_dataset.id}"

      # Store new archive and queue processing
      @scxrd_dataset.archive.attach(params[:scxrd_dataset][:compressed_archive])
      ScxrdArchiveProcessingJob.perform_later(@scxrd_dataset.id)
    end

    if @scxrd_dataset.update(scxrd_dataset_params)
      redirect_path = @well ? [ @well, @scxrd_dataset ] : @scxrd_dataset
      notice_text = params[:scxrd_dataset][:compressed_archive].present? ?
        "SCXRD dataset was successfully updated and is being reprocessed." :
        "SCXRD dataset was successfully updated."
      redirect_to redirect_path, notice: notice_text
    else
      # Note: Lattice centrings removed - primitive cells are always primitive
      render :edit
    end
  end

  def destroy
    @scxrd_dataset.destroy
    redirect_path = @well ? well_scxrd_datasets_path(@well) : scxrd_datasets_path
    redirect_to redirect_path, notice: "SCXRD dataset was successfully deleted."
  end

  def download
    if @scxrd_dataset.archive.attached?
      redirect_to rails_blob_path(@scxrd_dataset.archive, disposition: "attachment")
    else
      redirect_to [ @well, @scxrd_dataset ], alert: "No archive file attached."
    end
  end

  def download_peak_table
    if @scxrd_dataset.has_peak_table?
      redirect_to rails_blob_path(@scxrd_dataset.peak_table, disposition: "attachment")
    else
      redirect_to [ @well, @scxrd_dataset ], alert: "No peak table available."
    end
  end

  def crystal_image
    if @scxrd_dataset.has_crystal_image?
      redirect_to rails_blob_path(@scxrd_dataset.crystal_image, disposition: "inline")
    else
      head :not_found
    end
  end

  def structure_file
    if @scxrd_dataset.has_structure_file?
      # Serve the structure file content directly for CifVis to consume
      structure_content = @scxrd_dataset.structure_file.download
      content_type = case @scxrd_dataset.structure_file_format
      when "cif"
                       "chemical/x-cif"
      when "ins", "res"
                       "chemical/x-shelx"
      else
                       "text/plain"
      end

      response.headers["Content-Type"] = content_type
      response.headers["Cache-Control"] = "public, max-age=3600"
      render plain: structure_content
    else
      head :not_found
    end
  end

  def image_data
    Rails.logger.info "SCXRD: Serving parsed image data for dataset #{@scxrd_dataset.id}"

    # Get the first diffraction image from the diffraction_images association
    first_diffraction_image = @scxrd_dataset.diffraction_images.order(:run_number, :image_number).first

    unless first_diffraction_image&.rodhypix_file&.attached?
      render json: { error: "No diffraction images available" }, status: :not_found
      return
    end

    begin
      parsed_data = @scxrd_dataset.parsed_image_data

      if parsed_data[:success]
        # Set cache headers for parsed image data (cache for 1 hour)
        expires_in 1.hour, public: true

        # Option to send just a sample for testing (add ?sample=true to URL)
        image_data = parsed_data[:image_data]
        if params[:sample] == "true" && image_data&.any?
          sample_size = [ 1000, image_data.length ].min
          image_data = image_data.first(sample_size)
        end

        render json: {
          success: true,
          dimensions: parsed_data[:dimensions],
          pixel_size: parsed_data[:pixel_size],
          image_data: image_data,
          metadata: parsed_data[:metadata]
        }
      else
        render json: {
          success: false,
          error: parsed_data[:error] || "Failed to parse image data"
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "SCXRD: Error serving image data: #{e.message}"
      render json: {
        success: false,
        error: "Internal server error while processing image data"
      }, status: :internal_server_error
    end
  end

  def peak_table_data
    Rails.logger.info "SCXRD: Serving parsed peak table data for dataset #{@scxrd_dataset.id}"

    unless @scxrd_dataset.has_peak_table?
      render json: { error: "No peak table available" }, status: :not_found
      return
    end

    begin
      parsed_data = @scxrd_dataset.parsed_peak_table_data

      if parsed_data[:success]
        # Set cache headers for parsed peak table data (cache for 1 hour)
        expires_in 1.hour, public: true

        # Option to send just a sample for testing (add ?sample=true to URL)
        data_points = parsed_data[:data_points]
        if params[:sample] == "true" && data_points&.any?
          sample_size = [ 1000, data_points.length ].min
          data_points = data_points.first(sample_size)
        end

        render json: {
          success: true,
          data_points: data_points,
          statistics: parsed_data[:statistics],
          metadata: parsed_data[:metadata]
        }
      else
        render json: {
          success: false,
          error: parsed_data[:error] || "Failed to parse peak table data"
        }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "SCXRD: Error serving peak table data: #{e.message}"
      render json: {
        success: false,
        error: "Internal server error while processing peak table data"
      }, status: :internal_server_error
    end
  end

  private

  def log_request
  end

  def set_well
    return if params[:well_id].blank? || params[:well_id] == "null"
    @well = Well.find(params[:well_id])
  end

  def set_scxrd_dataset
    if @well
      @scxrd_dataset = @well.scxrd_datasets.find(params[:id])
    else
      @scxrd_dataset = ScxrdDataset.find(params[:id])
      @well = @scxrd_dataset.well  # Set well for use in views
    end
  end



  def scxrd_dataset_params
    # Create a copy of params without the compressed_archive to avoid unpermitted parameter warnings
    filtered_params = params.dup
    filtered_params[:scxrd_dataset] = params[:scxrd_dataset].except(:compressed_archive) if params[:scxrd_dataset]

    # Determine permitted parameters based on context
    permitted_params = [ :experiment_name, :measured_at, :crystal_image ]

    # Only allow well_id when we're in well context (not standalone)
    permitted_params << :well_id if @well.present?

    filtered_params.require(:scxrd_dataset).permit(*permitted_params)
  end
end
