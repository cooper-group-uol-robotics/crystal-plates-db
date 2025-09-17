class ScxrdDatasetsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  before_action :log_request
  before_action :set_well
  before_action :set_scxrd_dataset, only: [ :show, :edit, :update, :destroy, :download, :download_peak_table, :download_first_image, :image_data, :peak_table_data ]

  def index
    @scxrd_datasets = @well.scxrd_datasets.order(created_at: :desc)
    render partial: "scxrd_datasets/gallery", locals: { well: @well }
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @scxrd_dataset.id,
          experiment_name: @scxrd_dataset.experiment_name,
          date_measured: @scxrd_dataset.date_measured&.strftime("%Y-%m-%d"),
          lattice_centring: "primitive",  # Niggli reduced cells are always primitive
          has_peak_table: @scxrd_dataset.has_peak_table?,
          has_first_image: @scxrd_dataset.has_first_image?,
          has_archive: @scxrd_dataset.archive.attached?,
          peak_table_size: @scxrd_dataset.has_peak_table? ? number_to_human_size(@scxrd_dataset.peak_table_size) : nil,
          first_image_size: @scxrd_dataset.has_first_image? ? number_to_human_size(@scxrd_dataset.first_image_size) : nil,
          niggli_unit_cell: @scxrd_dataset.niggli_a.present? ? {
            a: number_with_precision(@scxrd_dataset.niggli_a, precision: 3),
            b: number_with_precision(@scxrd_dataset.niggli_b, precision: 3),
            c: number_with_precision(@scxrd_dataset.niggli_c, precision: 3),
            alpha: number_with_precision(@scxrd_dataset.niggli_alpha, precision: 1),
            beta: number_with_precision(@scxrd_dataset.niggli_beta, precision: 1),
            gamma: number_with_precision(@scxrd_dataset.niggli_gamma, precision: 1)
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
    @scxrd_dataset = @well.scxrd_datasets.build
    # Note: Lattice centrings removed - Niggli reduced cells are always primitive
  end

  def create
    # Extract compressed archive parameter before processing model params
    compressed_archive = params.dig(:scxrd_dataset, :compressed_archive)

    @scxrd_dataset = @well.scxrd_datasets.build(scxrd_dataset_params)
    @scxrd_dataset.date_uploaded = Time.current

    # Set measurement date to current date if not provided
    @scxrd_dataset.date_measured = Date.current if @scxrd_dataset.date_measured.blank?

    # Process uploaded compressed archive - this is required for new datasets
    if compressed_archive.present?
      process_compressed_archive(compressed_archive)
    else
      @scxrd_dataset.errors.add(:base, "Experiment folder is required")
    end

    if @scxrd_dataset.save
      redirect_to [ @well, @scxrd_dataset ], notice: "SCXRD dataset was successfully created."
    else
      Rails.logger.error "SCXRD: Failed to save dataset. Errors: #{@scxrd_dataset.errors.full_messages.join(', ')}"
      # Note: Lattice centrings removed - Niggli reduced cells are always primitive
      render :new
    end
  end

  def edit
    # Note: Lattice centrings removed - Niggli reduced cells are always primitive
  end

  def update
    # Process uploaded compressed archive if provided
    if params[:scxrd_dataset][:compressed_archive].present?
      process_compressed_archive(params[:scxrd_dataset][:compressed_archive])
    end

    if @scxrd_dataset.update(scxrd_dataset_params)
      redirect_to [ @well, @scxrd_dataset ], notice: "SCXRD dataset was successfully updated."
    else
      # Note: Lattice centrings removed - Niggli reduced cells are always primitive
      render :edit
    end
  end

  def destroy
    @scxrd_dataset.destroy
    redirect_to well_scxrd_datasets_path(@well), notice: "SCXRD dataset was successfully deleted."
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

  def download_first_image
    if @scxrd_dataset.has_first_image?
      redirect_to rails_blob_path(@scxrd_dataset.first_image, disposition: "attachment")
    else
      redirect_to [ @well, @scxrd_dataset ], alert: "No first diffraction image available."
    end
  end

  def image_data
    Rails.logger.info "SCXRD: Serving parsed image data for dataset #{@scxrd_dataset.id}"

    unless @scxrd_dataset.has_first_image?
      render json: { error: "No first diffraction image available" }, status: :not_found
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
    @well = Well.find(params[:well_id])
  end

  def set_scxrd_dataset
    @scxrd_dataset = @well.scxrd_datasets.find(params[:id])
  end

  def process_compressed_archive(uploaded_archive)
    return unless uploaded_archive.present?

    begin
      # Create a temporary directory to extract the archive
      Dir.mktmpdir do |temp_dir|
        # Save the uploaded archive temporarily
        archive_path = File.join(temp_dir, "uploaded_archive.zip")
        File.open(archive_path, "wb") { |f| f.write(uploaded_archive.read) }

        # Extract the archive
        extract_start_time = Time.current

        require "zip"
        Zip::File.open(archive_path) do |zip_file|
          file_count = 0
          zip_file.each do |entry|
            next if entry.directory?

            file_path = File.join(temp_dir, entry.name)
            FileUtils.mkdir_p(File.dirname(file_path))
            entry.extract(file_path)

            file_count += 1
          end
        end

        # Set experiment name from archive filename if not already set
        if @scxrd_dataset.experiment_name.blank?
          base_name = File.basename(uploaded_archive.original_filename, ".*")
          @scxrd_dataset.experiment_name = base_name
        end

        # Find the experiment folder (should be the first directory in the extracted files)
        experiment_folder = Dir.glob("#{temp_dir}/*").find { |path| File.directory?(path) }
        if experiment_folder

          processor = ScxrdFolderProcessorService.new(experiment_folder)
          result = processor.process

          Rails.logger.info "SCXRD: File processing completed, storing results..."

          # Store extracted data as Active Storage attachments
          if result[:peak_table]
            @scxrd_dataset.peak_table.attach(
              io: StringIO.new(result[:peak_table]),
              filename: "#{@scxrd_dataset.experiment_name}_peak_table.txt",
              content_type: "text/plain"
            )
            Rails.logger.info "SCXRD: Peak table stored (#{number_to_human_size(result[:peak_table].bytesize)})"
          end

          if result[:first_image]
            @scxrd_dataset.first_image.attach(
              io: StringIO.new(result[:first_image]),
              filename: "#{@scxrd_dataset.experiment_name}_first_frame.rodhypix",
              content_type: "application/octet-stream"
            )
            Rails.logger.info "SCXRD: First image stored (#{number_to_human_size(result[:first_image].bytesize)})"
          end

          # Store unit cell parameters from .par file if available
          Rails.logger.info "SCXRD: Checking for parsed .par data..."
          if result[:par_data]
            par_data = result[:par_data]
            Rails.logger.info "SCXRD: Found .par data: #{par_data.inspect}"

            @scxrd_dataset.niggli_a = par_data[:a] if par_data[:a]
            @scxrd_dataset.niggli_b = par_data[:b] if par_data[:b]
            @scxrd_dataset.niggli_c = par_data[:c] if par_data[:c]
            @scxrd_dataset.niggli_alpha = par_data[:alpha] if par_data[:alpha]
            @scxrd_dataset.niggli_beta = par_data[:beta] if par_data[:beta]
            @scxrd_dataset.niggli_gamma = par_data[:gamma] if par_data[:gamma]

            Rails.logger.info "SCXRD: Niggli unit cell parameters stored from .par file: a=#{@scxrd_dataset.niggli_a}, b=#{@scxrd_dataset.niggli_b}, c=#{@scxrd_dataset.niggli_c}, α=#{@scxrd_dataset.niggli_alpha}, β=#{@scxrd_dataset.niggli_beta}, γ=#{@scxrd_dataset.niggli_gamma}"

            # Store real world coordinates if parsed from cmdscript.mac, but only if not already provided by user
            parsed_coords_used = false

            if @scxrd_dataset.real_world_x_mm.blank? && par_data[:real_world_x_mm]
              @scxrd_dataset.real_world_x_mm = par_data[:real_world_x_mm]
              parsed_coords_used = true
            end

            if @scxrd_dataset.real_world_y_mm.blank? && par_data[:real_world_y_mm]
              @scxrd_dataset.real_world_y_mm = par_data[:real_world_y_mm]
              parsed_coords_used = true
            end

            if @scxrd_dataset.real_world_z_mm.blank? && par_data[:real_world_z_mm]
              @scxrd_dataset.real_world_z_mm = par_data[:real_world_z_mm]
              parsed_coords_used = true
            end

            if parsed_coords_used
              Rails.logger.info "SCXRD: Real world coordinates from cmdscript.mac used where not provided by user: x=#{@scxrd_dataset.real_world_x_mm}, y=#{@scxrd_dataset.real_world_y_mm}, z=#{@scxrd_dataset.real_world_z_mm}"
            elsif par_data[:real_world_x_mm] || par_data[:real_world_y_mm] || par_data[:real_world_z_mm]
              Rails.logger.info "SCXRD: Real world coordinates from cmdscript.mac ignored (user provided values take precedence): user=(#{@scxrd_dataset.real_world_x_mm}, #{@scxrd_dataset.real_world_y_mm}, #{@scxrd_dataset.real_world_z_mm})"
            else
              Rails.logger.info "SCXRD: No real world coordinates found in cmdscript.mac"
            end
          else
            Rails.logger.warn "SCXRD: No .par data found in processing result"
          end

          # Store the original archive as the zip attachment
          Rails.logger.info "SCXRD: Attaching original compressed archive (#{number_to_human_size(uploaded_archive.size)})"
          uploaded_archive.rewind  # Reset the file pointer
          @scxrd_dataset.archive.attach(uploaded_archive)
        else
          Rails.logger.warn "SCXRD: No experiment folder found in extracted archive"
          @scxrd_dataset.errors.add(:base, "No experiment folder found in the uploaded archive")
        end

        archive_end_time = Time.current
        Rails.logger.info "SCXRD: Total archive processing completed in #{(archive_end_time - archive_start_time).round(2)} seconds"
      end
    rescue => e
      Rails.logger.error "SCXRD: Error processing compressed archive: #{e.message}"
      Rails.logger.error "SCXRD: Backtrace: #{e.backtrace.first(5).join("\n")}"
      @scxrd_dataset.errors.add(:base, "Error processing compressed archive: #{e.message}")
    end
  end

  def scxrd_dataset_params
    # Create a copy of params without the compressed_archive to avoid unpermitted parameter warnings
    filtered_params = params.dup
    filtered_params[:scxrd_dataset] = params[:scxrd_dataset].except(:compressed_archive) if params[:scxrd_dataset]

    filtered_params.require(:scxrd_dataset).permit(:experiment_name, :date_measured,
                                                   :real_world_x_mm, :real_world_y_mm, :real_world_z_mm,
                                                   :niggli_a, :niggli_b, :niggli_c, :niggli_alpha, :niggli_beta, :niggli_gamma)
  end
end
