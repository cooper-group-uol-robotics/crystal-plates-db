class CalorimetryVideosController < ApplicationController
  before_action :set_calorimetry_video, only: [ :show, :edit, :update, :destroy ]

  # GET /calorimetry_videos
  def index
    @calorimetry_videos = CalorimetryVideo.recent.includes(:plate, video_file_attachment: :blob)
    @plates = Plate.order(:name) # For the upload form
  end

  # GET /calorimetry_videos/1
  def show
    @datasets = @calorimetry_video.calorimetry_datasets.recent.includes(:well)
  end

  # GET /calorimetry_videos/new
  def new
    @calorimetry_video = CalorimetryVideo.new
    @plates = Plate.order(:name)
  end

  # GET /calorimetry_videos/1/edit
  def edit
    @plates = Plate.order(:name)
  end

  # POST /calorimetry_videos
  def create
    @calorimetry_video = CalorimetryVideo.new(calorimetry_video_params)

    if @calorimetry_video.save
      redirect_to @calorimetry_video, notice: "Calorimetry video was successfully created."
    else
      @plates = Plate.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /calorimetry_videos/1
  def update
    if @calorimetry_video.update(calorimetry_video_params)
      redirect_to @calorimetry_video, notice: "Calorimetry video was successfully updated."
    else
      @plates = Plate.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /calorimetry_videos/1
  def destroy
    @calorimetry_video.destroy
    redirect_to calorimetry_videos_url, notice: "Calorimetry video was successfully deleted."
  end

  private

  def set_calorimetry_video
    @calorimetry_video = CalorimetryVideo.find(params[:id])
  end

  def calorimetry_video_params
    params.require(:calorimetry_video).permit(:name, :description, :recorded_at, :plate_id, :video_file)
  end
end
