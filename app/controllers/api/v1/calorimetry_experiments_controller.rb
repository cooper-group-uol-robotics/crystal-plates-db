class Api::V1::CalorimetryExperimentsController < Api::V1::BaseController
  before_action :set_plate, only: [ :index, :create ], if: -> { params[:plate_barcode].present? }
  before_action :set_calorimetry_experiment, only: [ :show, :update, :destroy ]

  # GET /api/v1/plates/:plate_barcode/calorimetry_experiments
  def index
    if params[:plate_barcode]
      @calorimetry_experiments = @plate.calorimetry_experiments.recent.includes(video_file_attachment: :blob)
    else
      @calorimetry_experiments = CalorimetryExperiment.recent.includes(:plate, video_file_attachment: :blob)
    end
    render json: @calorimetry_experiments.map { |experiment| format_calorimetry_experiment(experiment) }
  end

  # GET /api/v1/calorimetry_experiments/:id
  def show
    render json: format_calorimetry_experiment_detailed(@calorimetry_experiment)
  end

  # POST /api/v1/plates/:plate_barcode/calorimetry_experiments or POST /api/v1/calorimetry_experiments
  def create
    if params[:plate_barcode].present?
      set_plate
      @calorimetry_experiment = @plate.calorimetry_experiments.build(calorimetry_experiment_params)
    else
      @calorimetry_experiment = CalorimetryExperiment.new(calorimetry_experiment_params)
    end

    if @calorimetry_experiment.save
      render json: {
        data: format_calorimetry_experiment_detailed(@calorimetry_experiment),
        message: "Calorimetry experiment created successfully"
      }, status: :created
    else
      render json: {
        error: "Failed to create calorimetry experiment",
        details: @calorimetry_experiment.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/calorimetry_experiments/:id
  def update
    if @calorimetry_experiment.update(calorimetry_experiment_params)
      render json: {
        data: format_calorimetry_experiment_detailed(@calorimetry_experiment),
        message: "Calorimetry experiment updated successfully"
      }
    else
      render json: {
        error: "Failed to update calorimetry experiment",
        details: @calorimetry_experiment.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/calorimetry_experiments/:id
  def destroy
    @calorimetry_experiment.destroy
    render json: { message: "Calorimetry experiment deleted successfully" }
  end

  private

  def set_plate
    @plate = Plate.find_by!(barcode: params[:plate_barcode])
  end

  def set_calorimetry_experiment
    @calorimetry_experiment = CalorimetryExperiment.find(params[:id])
  end

  def calorimetry_experiment_params
    params.require(:calorimetry_experiment).permit(:name, :description, :recorded_at, :video_file, :plate_id)
  end

  def format_calorimetry_experiment(experiment)
    {
      id: experiment.id,
      name: experiment.name,
      description: experiment.description,
      recorded_at: experiment.recorded_at,
      plate: {
        id: experiment.plate.id,
        barcode: experiment.plate.barcode,
        name: experiment.plate.name
      },
      has_video_file: experiment.video_file.attached?,
      video_file_info: experiment.video_file.attached? ? {
        filename: experiment.video_file.filename.to_s,
        size: experiment.video_file.byte_size,
        content_type: experiment.video_file.content_type
      } : nil,
      dataset_count: experiment.calorimetry_datasets.count,
      created_at: experiment.created_at,
      updated_at: experiment.updated_at
    }
  end

  def format_calorimetry_experiment_detailed(experiment)
    base_data = format_calorimetry_experiment(experiment)

    base_data.merge({
      datasets: experiment.calorimetry_datasets.includes(:well).recent.map do |dataset|
        {
          id: dataset.id,
          name: dataset.name,
          well: {
            id: dataset.well.id,
            position: dataset.well.position,
            well_row: dataset.well.well_row,
            well_column: dataset.well.well_column
          },
          pixel_x: dataset.pixel_x,
          pixel_y: dataset.pixel_y,
          mask_diameter_pixels: dataset.mask_diameter_pixels,
          datapoint_count: dataset.datapoint_count,
          processed_at: dataset.processed_at
        }
      end
    })
  end
end
