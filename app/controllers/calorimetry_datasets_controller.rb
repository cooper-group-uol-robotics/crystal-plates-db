class CalorimetryDatasetsController < ApplicationController
  before_action :set_well, only: [ :index, :new, :create ], if: -> { params[:well_id].present? }
  before_action :set_calorimetry_dataset, only: [ :show, :edit, :update, :destroy ]

  # GET /calorimetry_datasets (standalone index for all datasets)
  def index
    @calorimetry_datasets = CalorimetryDataset.includes(:well, :calorimetry_video)
                                             .order(created_at: :desc)
                                             .page(params[:page])
                                             .per(20)
  end

  # GET /wells/:well_id/calorimetry_datasets/new or GET /calorimetry_datasets/new
  def new
    if params[:well_id].present?
      set_well unless @well
      @calorimetry_dataset = @well.calorimetry_datasets.build
    else
      @calorimetry_dataset = CalorimetryDataset.new
    end

    # Load available videos for the dropdown
    if @well.present?
      @available_videos = CalorimetryVideo.joins(:plate)
                                         .where(plates: { id: @well.plate_id })
                                         .order(created_at: :desc)
    else
      @available_videos = CalorimetryVideo.joins(:plate).order(created_at: :desc)
    end
  end

  # POST /wells/:well_id/calorimetry_datasets or POST /calorimetry_datasets
  def create
    if params[:well_id].present?
      set_well unless @well
      @calorimetry_dataset = @well.calorimetry_datasets.build(calorimetry_dataset_params)
      success_redirect = @well.plate
    else
      @calorimetry_dataset = CalorimetryDataset.new(calorimetry_dataset_params)
      success_redirect = @calorimetry_dataset
    end

    respond_to do |format|
      if @calorimetry_dataset.save
        format.html { redirect_to success_redirect, notice: "Calorimetry dataset was successfully created." }
        format.json { render json: @calorimetry_dataset, status: :created }
      else
        format.html {
          # Reload available videos for the dropdown
          if @well.present?
            @available_videos = CalorimetryVideo.joins(:plate)
                                               .where(plates: { id: @well.plate_id })
                                               .order(created_at: :desc)
          else
            @available_videos = CalorimetryVideo.joins(:plate).order(created_at: :desc)
          end
          render :new, status: :unprocessable_entity
        }
        format.json { render json: @calorimetry_dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /wells/:well_id/calorimetry_datasets/:id or GET /calorimetry_datasets/:id
  def show
    # For individual dataset viewing
  end

  # GET /wells/:well_id/calorimetry_datasets/:id/edit or GET /calorimetry_datasets/:id/edit
  def edit
    # Load available videos for the dropdown
    if @calorimetry_dataset.well.present?
      @available_videos = CalorimetryVideo.joins(:plate)
                                         .where(plates: { id: @calorimetry_dataset.well.plate_id })
                                         .order(created_at: :desc)
    else
      @available_videos = CalorimetryVideo.joins(:plate).order(created_at: :desc)
    end
  end

  # PATCH/PUT /calorimetry_datasets/:id
  def update
    respond_to do |format|
      if @calorimetry_dataset.update(calorimetry_dataset_params)
        success_redirect = @calorimetry_dataset.well.present? ? @calorimetry_dataset.well.plate : @calorimetry_dataset
        format.html { redirect_to success_redirect, notice: "Calorimetry dataset was successfully updated." }
        format.json { render json: @calorimetry_dataset }
      else
        format.html {
          # Reload available videos for the dropdown
          if @calorimetry_dataset.well.present?
            @available_videos = CalorimetryVideo.joins(:plate)
                                               .where(plates: { id: @calorimetry_dataset.well.plate_id })
                                               .order(created_at: :desc)
          else
            @available_videos = CalorimetryVideo.joins(:plate).order(created_at: :desc)
          end
          render :edit, status: :unprocessable_entity
        }
        format.json { render json: @calorimetry_dataset.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /calorimetry_datasets/:id/plot
  def plot
    dataset = CalorimetryDataset.find(params[:id])
    render partial: "calorimetry_datasets/plot", locals: { calorimetry_dataset: dataset }
  end

  # DELETE /calorimetry_datasets/:id
  def destroy
    well = @calorimetry_dataset.well
    @calorimetry_dataset.destroy!

    respond_to do |format|
      success_redirect = well.present? ? well.plate : calorimetry_datasets_path
      format.html { redirect_to success_redirect, status: :see_other, notice: "Calorimetry dataset was successfully deleted." }
      format.json { head :no_content }
    end
  end

  private

  def set_well
    @well = Well.find(params[:well_id])
  end

  def set_calorimetry_dataset
    @calorimetry_dataset = CalorimetryDataset.find(params[:id])
  end

  def calorimetry_dataset_params
    params.require(:calorimetry_dataset).permit(:name, :calorimetry_video_id, :pixel_x, :pixel_y, :mask_diameter_pixels, :temperature_data_file)
  end
end
