class Api::V1::CalorimetryDatasetsController < Api::V1::BaseController
  before_action :set_well, only: [ :index, :create ], if: -> { params[:well_id].present? }
  before_action :set_calorimetry_dataset, only: [ :show, :update, :destroy, :datapoints ]

  # GET /api/v1/wells/:well_id/calorimetry_datasets
  def index
    if params[:well_id]
      @calorimetry_datasets = @well.calorimetry_datasets.recent.includes(:calorimetry_video)
    else
      @calorimetry_datasets = CalorimetryDataset.recent.includes(:well, :calorimetry_video)
    end
    render json: @calorimetry_datasets.map { |dataset| format_calorimetry_dataset(dataset) }
  end

  # GET /api/v1/calorimetry_datasets/:id
  def show
    render json: format_calorimetry_dataset_detailed(@calorimetry_dataset)
  end

  # GET /api/v1/calorimetry_datasets/:id/datapoints
  def datapoints
    datapoints = @calorimetry_dataset.calorimetry_datapoints.ordered

    # Optional time range filtering
    if params[:start_time].present? && params[:end_time].present?
      start_time = params[:start_time].to_f
      end_time = params[:end_time].to_f
      datapoints = datapoints.in_time_range(start_time, end_time)
    end

    # Optional decimation for large datasets
    if params[:max_points].present?
      max_points = params[:max_points].to_i
      total_points = datapoints.count

      if total_points > max_points
        # Simple decimation - take every nth point
        step = (total_points.to_f / max_points).ceil
        datapoints = datapoints.where("id % ? = 0", step)
      end
    end

    render json: {
      data: datapoints.pluck(:timestamp_seconds, :temperature).map do |timestamp, temp|
        { timestamp_seconds: timestamp, temperature: temp }
      end,
      metadata: {
        total_points: @calorimetry_dataset.datapoint_count,
        time_range: {
          start: @calorimetry_dataset.calorimetry_datapoints.minimum(:timestamp_seconds),
          end: @calorimetry_dataset.calorimetry_datapoints.maximum(:timestamp_seconds)
        },
        temperature_range: @calorimetry_dataset.temperature_range,
        duration_seconds: @calorimetry_dataset.duration_seconds
      }
    }
  end

  # POST /api/v1/wells/:well_id/calorimetry_datasets or POST /api/v1/calorimetry_datasets
  def create
    if params[:well_id].present?
      set_well
      @calorimetry_dataset = @well.calorimetry_datasets.build(calorimetry_dataset_params)
    else
      @calorimetry_dataset = CalorimetryDataset.new(calorimetry_dataset_params)
    end

    if @calorimetry_dataset.save
      # Process datapoints if provided
      if params[:datapoints].present?
        create_datapoints(@calorimetry_dataset, params[:datapoints])
      end

      render json: {
        data: format_calorimetry_dataset_detailed(@calorimetry_dataset),
        message: "Calorimetry dataset created successfully"
      }, status: :created
    else
      render json: {
        error: "Failed to create calorimetry dataset",
        details: @calorimetry_dataset.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/calorimetry_datasets/:id
  def update
    if @calorimetry_dataset.update(calorimetry_dataset_params)
      # Update datapoints if provided
      if params[:datapoints].present?
        @calorimetry_dataset.calorimetry_datapoints.destroy_all
        create_datapoints(@calorimetry_dataset, params[:datapoints])
      end

      render json: {
        data: format_calorimetry_dataset_detailed(@calorimetry_dataset),
        message: "Calorimetry dataset updated successfully"
      }
    else
      render json: {
        error: "Failed to update calorimetry dataset",
        details: @calorimetry_dataset.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/calorimetry_datasets/:id
  def destroy
    @calorimetry_dataset.destroy
    render json: { message: "Calorimetry dataset deleted successfully" }
  end

  private

  def set_well
    @well = Well.find(params[:well_id])
  end

  def set_calorimetry_dataset
    @calorimetry_dataset = CalorimetryDataset.find(params[:id])
  end

  def calorimetry_dataset_params
    params.require(:calorimetry_dataset).permit(
      :name, :pixel_x, :pixel_y, :mask_diameter_pixels, :processed_at,
      :well_id, :calorimetry_video_id
    )
  end

  def create_datapoints(dataset, datapoints_data)
    return unless datapoints_data.is_a?(Array)

    datapoint_records = datapoints_data.map do |point|
      {
        calorimetry_dataset_id: dataset.id,
        timestamp_seconds: point[:timestamp_seconds] || point["timestamp_seconds"],
        temperature: point[:temperature] || point["temperature"],
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # Bulk insert for performance
    CalorimetryDatapoint.insert_all(datapoint_records) if datapoint_records.any?
  end

  def format_calorimetry_dataset(dataset)
    {
      id: dataset.id,
      name: dataset.name,
      well: {
        id: dataset.well.id,
        position: dataset.well.position,
        well_row: dataset.well.well_row,
        well_column: dataset.well.well_column
      },
      calorimetry_video: {
        id: dataset.calorimetry_video.id,
        name: dataset.calorimetry_video.name,
        recorded_at: dataset.calorimetry_video.recorded_at
      },
      processing_parameters: {
        pixel_x: dataset.pixel_x,
        pixel_y: dataset.pixel_y,
        mask_diameter_pixels: dataset.mask_diameter_pixels
      },
      datapoint_count: dataset.datapoint_count,
      temperature_range: dataset.temperature_range,
      duration_seconds: dataset.duration_seconds,
      processed_at: dataset.processed_at,
      created_at: dataset.created_at,
      updated_at: dataset.updated_at
    }
  end

  def format_calorimetry_dataset_detailed(dataset)
    base_data = format_calorimetry_dataset(dataset)

    base_data.merge({
      plate: {
        id: dataset.calorimetry_video.plate.id,
        barcode: dataset.calorimetry_video.plate.barcode,
        name: dataset.calorimetry_video.plate.name
      }
    })
  end
end
