class Api::V1::ScxrdDatasetsController < Api::V1::BaseController
  include ActionView::Helpers::NumberHelper
  before_action :set_well, if: -> { params[:well_id].present? && params[:well_id] != "null" }
  before_action :set_scxrd_dataset, only: [ :show, :update, :destroy ]

  # GET /api/v1/wells/:well_id/scxrd_datasets or GET /api/v1/scxrd_datasets (standalone)
  def index
    if @well
      @scxrd_datasets = @well.scxrd_datasets.order(created_at: :desc)
      render json: {
        well_id: @well.id,
        well_label: @well.well_label,
        count: @scxrd_datasets.count,
        scxrd_datasets: @scxrd_datasets.map { |dataset| dataset_json(dataset) }
      }
    else
      # Standalone index - all datasets
      @scxrd_datasets = ScxrdDataset.includes(:well).order(created_at: :desc)
      render json: {
        count: @scxrd_datasets.count,
        scxrd_datasets: @scxrd_datasets.map { |dataset| dataset_json(dataset) }
      }
    end
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/:id
  def show
    render json: {
      scxrd_dataset: detailed_dataset_json(@scxrd_dataset)
    }
  end

  # POST /api/v1/wells/:well_id/scxrd_datasets or POST /api/v1/scxrd_datasets (standalone)
  def create
    dataset_params = scxrd_dataset_params

    # Convert unit cell parameters to primitive if provided
    dataset_params = ensure_primitive_cell_params(dataset_params)

    if @well
      @scxrd_dataset = @well.scxrd_datasets.build(dataset_params)
    else
      @scxrd_dataset = ScxrdDataset.new(dataset_params)
    end

    if @scxrd_dataset.save
      render json: {
        message: "SCXRD dataset created successfully",
        scxrd_dataset: detailed_dataset_json(@scxrd_dataset)
      }, status: :created
    else
      render json: {
        error: "Failed to create SCXRD dataset",
        errors: @scxrd_dataset.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/wells/:well_id/scxrd_datasets/:id
  def update
    dataset_params = scxrd_dataset_params

    # Convert unit cell parameters to primitive if provided
    dataset_params = ensure_primitive_cell_params(dataset_params)

    if @scxrd_dataset.update(dataset_params)
      render json: {
        message: "SCXRD dataset updated successfully",
        scxrd_dataset: detailed_dataset_json(@scxrd_dataset)
      }
    else
      render json: {
        error: "Failed to update SCXRD dataset",
        errors: @scxrd_dataset.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/wells/:well_id/scxrd_datasets/:id
  def destroy
    @scxrd_dataset.destroy
    render json: {
      message: "SCXRD dataset deleted successfully"
    }
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/:id/image_data
  def image_data
    unless @scxrd_dataset.has_first_image?
      render json: { error: "No diffraction image available" }, status: :not_found
      return
    end

    parsed_data = @scxrd_dataset.parsed_image_data

    if parsed_data[:success]
      render json: {
        success: true,
        dimensions: parsed_data[:dimensions],
        pixel_size: parsed_data[:pixel_size],
        metadata: parsed_data[:metadata],
        image_data: parsed_data[:image_data]
      }
    else
      render json: {
        success: false,
        error: parsed_data[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/correlations
  def spatial_correlations
    # Return empty correlations for standalone datasets (no well)
    unless @well
      render json: {
        well_id: nil,
        well_label: nil,
        tolerance_mm: params[:tolerance_mm]&.to_f || 0.5,
        correlations_count: 0,
        correlations: [],
        message: "Spatial correlations not available for standalone datasets"
      }
      return
    end

    tolerance_mm = params[:tolerance_mm]&.to_f || 0.5
    correlations = ScxrdDataset.spatial_correlations_for_well(@well, tolerance_mm)

    render json: {
      well_id: @well.id,
      well_label: @well.well_label,
      tolerance_mm: tolerance_mm,
      correlations_count: correlations.count,
      correlations: correlations.map do |corr|
        {
          scxrd_dataset: dataset_json(corr[:scxrd_dataset]),
          point_of_interests: corr[:distances].map do |dist_info|
            poi = dist_info[:poi]
            coords = poi.real_world_coordinates
            {
              id: poi.id,
              point_type: poi.point_type,
              pixel_coordinates: { x: poi.pixel_x, y: poi.pixel_y },
              real_world_coordinates: coords,
              distance_mm: dist_info[:distance_mm]&.round(3),
              image_id: poi.image_id,
              marked_at: poi.marked_at
            }
          end
        }
      end
    }
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/search
  def search
    datasets = @well.scxrd_datasets

    # Filter by experiment name
    if params[:experiment_name].present?
      datasets = datasets.where("experiment_name ILIKE ?", "%#{params[:experiment_name]}%")
    end

    # Filter by date range
    if params[:date_from].present?
      datasets = datasets.where("measured_at >= ?", Date.parse(params[:date_from]))
    end

    if params[:date_to].present?
      datasets = datasets.where("measured_at <= ?", Date.parse(params[:date_to]))
    end

    # Note: Lattice centering filtering removed as primitive cells are always primitive

    # Filter by coordinate proximity
    if params[:near_x].present? && params[:near_y].present?
      tolerance = params[:tolerance_mm]&.to_f || 1.0
      datasets = datasets.near_coordinates(
        params[:near_x].to_f,
        params[:near_y].to_f,
        tolerance
      )
    end

    # Filter by unit cell parameters (with tolerance)
    if params[:unit_cell].present?
      cell_params = params[:unit_cell]
      tolerance_percent = params[:cell_tolerance_percent]&.to_f || 5.0

      %w[primitive_a primitive_b primitive_c primitive_alpha primitive_beta primitive_gamma].each do |param|
        old_param = param.sub("primitive_", "")
        if cell_params[old_param].present?
          value = cell_params[old_param].to_f
          tolerance_abs = value * (tolerance_percent / 100.0)
          datasets = datasets.where(
            "#{param} BETWEEN ? AND ?",
            value - tolerance_abs,
            value + tolerance_abs
          )
        end
      end
    end

    datasets = datasets.order(created_at: :desc).limit(100)

    render json: {
      well_id: @well.id,
      search_params: params.except(:controller, :action, :well_id),
      results_count: datasets.count,
      scxrd_datasets: datasets.map { |dataset| dataset_json(dataset) }
    }
  end

  # POST /api/v1/scxrd_datasets/upload_archive
  def upload_archive
    compressed_archive = params[:archive] || params.dig(:scxrd_dataset, :archive_file)

    unless compressed_archive.present?
      render json: { error: "Archive file is required" }, status: :unprocessable_entity
      return
    end

    @scxrd_dataset = ScxrdDataset.new(
      experiment_name: "Processing...",
      measured_at: Time.current
    )

    if @scxrd_dataset.save
      # Attach the archive file
      compressed_archive.rewind if compressed_archive.respond_to?(:rewind)
      @scxrd_dataset.archive.attach(compressed_archive)

      # Kick off background job for processing
      ScxrdArchiveProcessingJob.perform_later(@scxrd_dataset.id)

      render json: {
        message: "Archive received. Processing will continue in background.",
        scxrd_dataset_id: @scxrd_dataset.id,
        status: "processing"
      }, status: :accepted
    else
      render json: {
        error: "Failed to create SCXRD dataset",
        errors: @scxrd_dataset.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  # Ensure unit cell parameters are primitive before saving to database
  def ensure_primitive_cell_params(params)
    # Check if unit cell parameters are provided
    if params[:primitive_a].present? && params[:primitive_b].present? && params[:primitive_c].present? &&
       params[:primitive_alpha].present? && params[:primitive_beta].present? && params[:primitive_gamma].present?

      original_a = params[:primitive_a].to_f
      original_b = params[:primitive_b].to_f
      original_c = params[:primitive_c].to_f
      original_alpha = params[:primitive_alpha].to_f
      original_beta = params[:primitive_beta].to_f
      original_gamma = params[:primitive_gamma].to_f

      # Convert to primitive using PrimitiveCellService
      if PrimitiveCellService.enabled?
        primitive_cell = PrimitiveCellService.ensure_primitive(
          original_a, original_b, original_c,
          original_alpha, original_beta, original_gamma
        )

        if primitive_cell
          Rails.logger.info "API Controller: Converted unit cell to primitive form"
          params[:primitive_a] = primitive_cell[:a]
          params[:primitive_b] = primitive_cell[:b]
          params[:primitive_c] = primitive_cell[:c]
          params[:primitive_alpha] = primitive_cell[:alpha]
          params[:primitive_beta] = primitive_cell[:beta]
          params[:primitive_gamma] = primitive_cell[:gamma]
        else
          Rails.logger.warn "API Controller: Failed to convert unit cell to primitive, using original values"
        end
      else
        Rails.logger.info "API Controller: PrimitiveCellService disabled, using provided cell parameters as-is"
      end
    end

    params
  end

  def set_well
    return if params[:well_id].blank? || params[:well_id] == "null"
    @well = Well.find(params[:well_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Well not found" }, status: :not_found
  end

  def set_scxrd_dataset
    if @well
      @scxrd_dataset = @well.scxrd_datasets.find(params[:id])
    else
      @scxrd_dataset = ScxrdDataset.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "SCXRD dataset not found" }, status: :not_found
  end

  def scxrd_dataset_params
    params.require(:scxrd_dataset).permit(
      :experiment_name, :measured_at,
      :real_world_x_mm, :real_world_y_mm, :real_world_z_mm,
      :primitive_a, :primitive_b, :primitive_c, :primitive_alpha, :primitive_beta, :primitive_gamma
    )
  end

  def dataset_json(dataset)
    {
      id: dataset.id,
      experiment_name: dataset.experiment_name,
      measured_at: dataset.measured_at&.strftime("%Y-%m-%d %H:%M:%S"),

      lattice_centring: dataset.display_cell&.dig(:bravais) || "primitive",
      real_world_coordinates: (dataset.real_world_x_mm || dataset.real_world_y_mm || dataset.real_world_z_mm) ? {
        x_mm: dataset.real_world_x_mm,
        y_mm: dataset.real_world_y_mm,
        z_mm: dataset.real_world_z_mm
      } : nil,
      primitive_unit_cell: dataset.has_primitive_cell? ? {
        a: number_with_precision(dataset.primitive_a, precision: 3),
        b: number_with_precision(dataset.primitive_b, precision: 3),
        c: number_with_precision(dataset.primitive_c, precision: 3),
        alpha: number_with_precision(dataset.primitive_alpha, precision: 1),
        beta: number_with_precision(dataset.primitive_beta, precision: 1),
        gamma: number_with_precision(dataset.primitive_gamma, precision: 1)
      } : nil,
      unit_cell: dataset.display_cell ? {
        a: number_with_precision(dataset.display_cell[:a], precision: 3),
        b: number_with_precision(dataset.display_cell[:b], precision: 3),
        c: number_with_precision(dataset.display_cell[:c], precision: 3),
        alpha: number_with_precision(dataset.display_cell[:alpha], precision: 1),
        beta: number_with_precision(dataset.display_cell[:beta], precision: 1),
        gamma: number_with_precision(dataset.display_cell[:gamma], precision: 1),
        bravais: dataset.display_cell[:bravais],
        conversion_distance: dataset.display_cell[:distance]
      } : nil,
      has_archive: dataset.archive.attached?,
      has_peak_table: dataset.has_peak_table?,
      has_first_image: dataset.has_first_image?,
      created_at: dataset.created_at,
      updated_at: dataset.updated_at
    }
  end

  def detailed_dataset_json(dataset)
    base_json = dataset_json(dataset)
    base_json.merge({
      peak_table_size: dataset.has_peak_table? ? number_to_human_size(dataset.peak_table_size) : nil,
      first_image_size: dataset.has_first_image? ? number_to_human_size(dataset.first_image_size) : nil,
      has_diffraction_images: dataset.has_diffraction_images?,
      diffraction_images_count: dataset.diffraction_images_count,
      total_diffraction_images_size: dataset.has_diffraction_images? ? number_to_human_size(dataset.total_diffraction_images_size) : nil,
      image_metadata: dataset.has_first_image? ? dataset.image_metadata : nil,
      nearby_point_of_interests: dataset.has_real_world_coordinates? ?
        dataset.nearby_point_of_interests.map do |poi|
          coords = poi.real_world_coordinates
          {
            id: poi.id,
            point_type: poi.point_type,
            pixel_coordinates: { x: poi.pixel_x, y: poi.pixel_y },
            real_world_coordinates: coords,
            distance_mm: dataset.distance_to_coordinates(coords[:x_mm], coords[:y_mm], coords[:z_mm])&.round(3),
            image_id: poi.image_id
          }
        end : []
    })
  end

  def process_compressed_archive(uploaded_archive)
    return unless uploaded_archive.present?

    begin
      archive_start_time = Time.current
      # Create a temporary directory to extract the archive
      Dir.mktmpdir do |temp_dir|
        # Save the uploaded archive temporarily
        archive_path = File.join(temp_dir, "uploaded_archive.zip")
        File.open(archive_path, "wb") { |f| f.write(uploaded_archive.read) }

        # Extract the archive
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
        if @scxrd_dataset.experiment_name.blank? || @scxrd_dataset.experiment_name == "Processing..."
          base_name = File.basename(uploaded_archive.original_filename, ".*")
          @scxrd_dataset.experiment_name = base_name
        end

        # Find the experiment folder (should be the first directory in the extracted files)
        experiment_folder = Dir.glob("#{temp_dir}/*").find { |path| File.directory?(path) }
        if experiment_folder

          processor = ScxrdFolderProcessorService.new(experiment_folder)
          result = processor.process

          Rails.logger.info "API SCXRD: File processing completed, storing results..."

          # Store extracted data as Active Storage attachments
          if result[:peak_table]
            @scxrd_dataset.peak_table.attach(
              io: StringIO.new(result[:peak_table]),
              filename: "#{@scxrd_dataset.experiment_name}_peak_table.txt",
              content_type: "text/plain"
            )
            Rails.logger.info "API SCXRD: Peak table stored (#{number_to_human_size(result[:peak_table].bytesize)})"
          end

          # Store all diffraction images as DiffractionImage records
          if result[:all_diffraction_images] && result[:all_diffraction_images].any?
            Rails.logger.info "API SCXRD: Processing #{result[:all_diffraction_images].length} diffraction images..."

            result[:all_diffraction_images].each_with_index do |image_data, index|
              begin
                diffraction_image = @scxrd_dataset.diffraction_images.build(
                  run_number: image_data[:run_number],
                  image_number: image_data[:image_number],
                  filename: image_data[:filename],
                  file_size: image_data[:file_size]
                )

                diffraction_image.rodhypix_file.attach(
                  io: StringIO.new(image_data[:data]),
                  filename: image_data[:filename],
                  content_type: "application/octet-stream"
                )

                diffraction_image.save!

                # Log progress every 100 images to avoid log spam
                if (index + 1) % 100 == 0 || index == result[:all_diffraction_images].length - 1
                  Rails.logger.info "API SCXRD: Stored #{index + 1}/#{result[:all_diffraction_images].length} diffraction images"
                end

              rescue => e
                Rails.logger.error "API SCXRD: Error storing diffraction image #{image_data[:filename]}: #{e.message}"
              end
            end

            total_size = result[:all_diffraction_images].sum { |img| img[:file_size] }
            Rails.logger.info "API SCXRD: All diffraction images stored (#{result[:all_diffraction_images].length} images, #{number_to_human_size(total_size)} total)"
          end

          # Store unit cell parameters from .par file, ensuring they are primitive
          Rails.logger.info "API SCXRD: Checking for parsed .par data..."
          if result[:metadata]
            metadata = result[:metadata]
            Rails.logger.info "API SCXRD: Found .par data: #{metadata.inspect}"

            # Extract unit cell parameters from metadata
            if metadata[:a] && metadata[:b] && metadata[:c] && metadata[:alpha] && metadata[:beta] && metadata[:gamma]
              original_a = metadata[:a]
              original_b = metadata[:b]
              original_c = metadata[:c]
              original_alpha = metadata[:alpha]
              original_beta = metadata[:beta]
              original_gamma = metadata[:gamma]

              Rails.logger.info "API SCXRD: Original unit cell parameters: a=#{original_a}, b=#{original_b}, c=#{original_c}, α=#{original_alpha}, β=#{original_beta}, γ=#{original_gamma}"

              # Convert to primitive cell using the PrimitiveCellService
              if PrimitiveCellService.enabled?
                primitive_cell = PrimitiveCellService.ensure_primitive(
                  original_a, original_b, original_c,
                  original_alpha, original_beta, original_gamma
                )

                if primitive_cell
                  @scxrd_dataset.primitive_a = primitive_cell[:a]
                  @scxrd_dataset.primitive_b = primitive_cell[:b]
                  @scxrd_dataset.primitive_c = primitive_cell[:c]
                  @scxrd_dataset.primitive_alpha = primitive_cell[:alpha]
                  @scxrd_dataset.primitive_beta = primitive_cell[:beta]
                  @scxrd_dataset.primitive_gamma = primitive_cell[:gamma]

                  Rails.logger.info "API SCXRD: Primitive unit cell parameters stored: a=#{@scxrd_dataset.primitive_a}, b=#{@scxrd_dataset.primitive_b}, c=#{@scxrd_dataset.primitive_c}, α=#{@scxrd_dataset.primitive_alpha}, β=#{@scxrd_dataset.primitive_beta}, γ=#{@scxrd_dataset.primitive_gamma}"
                else
                  Rails.logger.warn "API SCXRD: Failed to convert to primitive cell, storing original parameters"
                  @scxrd_dataset.primitive_a = original_a
                  @scxrd_dataset.primitive_b = original_b
                  @scxrd_dataset.primitive_c = original_c
                  @scxrd_dataset.primitive_alpha = original_alpha
                  @scxrd_dataset.primitive_beta = original_beta
                  @scxrd_dataset.primitive_gamma = original_gamma
                end
              else
                Rails.logger.warn "API SCXRD: PrimitiveCellService is disabled, storing original parameters"
                @scxrd_dataset.primitive_a = original_a
                @scxrd_dataset.primitive_b = original_b
                @scxrd_dataset.primitive_c = original_c
                @scxrd_dataset.primitive_alpha = original_alpha
                @scxrd_dataset.primitive_beta = original_beta
                @scxrd_dataset.primitive_gamma = original_gamma
              end
            else
              Rails.logger.warn "API SCXRD: Incomplete unit cell parameters in metadata"
            end

            # Store measurement time from datacoll.ini if available (takes precedence over default)
            if metadata[:measured_at]
              @scxrd_dataset.measured_at = metadata[:measured_at]
              Rails.logger.info "API SCXRD: Measurement time from datacoll.ini: #{@scxrd_dataset.measured_at}"
            else
              Rails.logger.info "API SCXRD: No measurement time found in datacoll.ini, using default date: #{@scxrd_dataset.measured_at}"
            end
          else
            Rails.logger.warn "API SCXRD: No .par data found in processing result"
          end

          # Store crystal image if available and no image is already attached
          if result[:crystal_image] && !@scxrd_dataset.crystal_image.attached?
            Rails.logger.info "API SCXRD: Attaching crystal image from archive (#{number_to_human_size(result[:crystal_image][:data].bytesize)})"
            @scxrd_dataset.crystal_image.attach(
              io: StringIO.new(result[:crystal_image][:data]),
              filename: result[:crystal_image][:filename],
              content_type: result[:crystal_image][:content_type]
            )
          elsif result[:crystal_image]
            Rails.logger.info "API SCXRD: Crystal image found in archive but dataset already has an image attached, skipping"
          end

          # Store structure file if available and no structure file is already attached
          if result[:structure_file] && !@scxrd_dataset.structure_file.attached?
            Rails.logger.info "API SCXRD: Attaching structure file from archive: #{result[:structure_file][:filename]} (#{number_to_human_size(result[:structure_file][:data].bytesize)})"
            @scxrd_dataset.structure_file.attach(
              io: StringIO.new(result[:structure_file][:data]),
              filename: result[:structure_file][:filename],
              content_type: result[:structure_file][:content_type]
            )
          elsif result[:structure_file]
            Rails.logger.info "API SCXRD: Structure file found in archive but dataset already has a structure file attached, skipping"
          end

          # Store the original archive as the zip attachment
          Rails.logger.info "API SCXRD: Attaching original compressed archive (#{number_to_human_size(uploaded_archive.size)})"
          uploaded_archive.rewind  # Reset the file pointer
          @scxrd_dataset.archive.attach(uploaded_archive)
        else
          Rails.logger.warn "API SCXRD: No experiment folder found in extracted archive"
          @scxrd_dataset.errors.add(:base, "No experiment folder found in the uploaded archive")
        end

        archive_end_time = Time.current
        Rails.logger.info "API SCXRD: Total archive processing completed in #{(archive_end_time - archive_start_time).round(2)} seconds"
      end
    rescue => e
      Rails.logger.error "API SCXRD: Error processing compressed archive: #{e.message}"
      Rails.logger.error "API SCXRD: Backtrace: #{e.backtrace.first(5).join("\n")}"
      @scxrd_dataset.errors.add(:base, "Error processing compressed archive: #{e.message}")
      raise e # Re-raise the error so it can be caught by the calling method
    end
  end
end
