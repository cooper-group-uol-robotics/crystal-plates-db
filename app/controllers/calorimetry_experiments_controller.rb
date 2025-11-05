class CalorimetryExperimentsController < ApplicationController
  before_action :set_calorimetry_experiment, only: [ :show, :edit, :update, :destroy ]

  # GET /calorimetry_experiments
  def index
    @calorimetry_experiments = CalorimetryExperiment.recent.includes(:plate, video_file_attachment: :blob)
    @plates = Plate.order(:name) # For the create form
  end

  # GET /calorimetry_experiments/1
  def show
    @datasets = @calorimetry_experiment.calorimetry_datasets.recent.includes(:well)
  end

  # GET /calorimetry_experiments/new
  def new
    @calorimetry_experiment = CalorimetryExperiment.new
    @plates = Plate.order(:name)
  end

  # GET /calorimetry_experiments/1/edit
  def edit
    @plates = Plate.order(:name)
  end

  # POST /calorimetry_experiments
  def create
    @calorimetry_experiment = CalorimetryExperiment.new(calorimetry_experiment_params)

    if @calorimetry_experiment.save
      redirect_to @calorimetry_experiment, notice: "Calorimetry experiment was successfully created."
    else
      @plates = Plate.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /calorimetry_experiments/1
  def update
    if @calorimetry_experiment.update(calorimetry_experiment_params)
      redirect_to @calorimetry_experiment, notice: "Calorimetry experiment was successfully updated."
    else
      @plates = Plate.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /calorimetry_experiments/1
  def destroy
    @calorimetry_experiment.destroy
    redirect_to calorimetry_experiments_url, notice: "Calorimetry experiment was successfully deleted."
  end

  private

  def set_calorimetry_experiment
    @calorimetry_experiment = CalorimetryExperiment.find(params[:id])
  end

  def calorimetry_experiment_params
    params.require(:calorimetry_experiment).permit(:name, :description, :recorded_at, :plate_id, :video_file)
  end
end
