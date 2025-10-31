class Api::V1::CalorimetryVideosController < Api::V1::BaseController
  before_action :set_plate, only: [ :index, :create ], if: -> { params[:plate_barcode].present? }
  before_action :set_calorimetry_video, only: [ :show, :update, :destroy ]

  # GET /api/v1/plates/:plate_barcode/calorimetry_videos
  def index
    if params[:plate_barcode]
      @calorimetry_videos = @plate.calorimetry_videos.recent.includes(video_file_attachment: :blob)
    else
      @calorimetry_videos = CalorimetryVideo.recent.includes(:plate, video_file_attachment: :blob)
    end
    render json: @calorimetry_videos.map { |video| format_calorimetry_video(video) }
  end

  # GET /api/v1/calorimetry_videos/:id
  def show
    render json: format_calorimetry_video_detailed(@calorimetry_video)
  end

  # POST /api/v1/plates/:plate_barcode/calorimetry_videos or POST /api/v1/calorimetry_videos
  def create
    if params[:plate_barcode].present?
      set_plate
      @calorimetry_video = @plate.calorimetry_videos.build(calorimetry_video_params)
    else
      @calorimetry_video = CalorimetryVideo.new(calorimetry_video_params)
    end

    if @calorimetry_video.save
      render json: {
        data: format_calorimetry_video_detailed(@calorimetry_video),
        message: "Calorimetry video created successfully"
      }, status: :created
    else
      render json: {
        error: "Failed to create calorimetry video",
        details: @calorimetry_video.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/calorimetry_videos/:id
  def update
    if @calorimetry_video.update(calorimetry_video_params)
      render json: {
        data: format_calorimetry_video_detailed(@calorimetry_video),
        message: "Calorimetry video updated successfully"
      }
    else
      render json: {
        error: "Failed to update calorimetry video",
        details: @calorimetry_video.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/calorimetry_videos/:id
  def destroy
    @calorimetry_video.destroy
    render json: { message: "Calorimetry video deleted successfully" }
  end

  private

  def set_plate
    @plate = Plate.find_by!(barcode: params[:plate_barcode])
  end

  def set_calorimetry_video
    @calorimetry_video = CalorimetryVideo.find(params[:id])
  end

  def calorimetry_video_params
    params.require(:calorimetry_video).permit(:name, :description, :recorded_at, :video_file, :plate_id)
  end

  def format_calorimetry_video(video)
    {
      id: video.id,
      name: video.name,
      description: video.description,
      recorded_at: video.recorded_at,
      plate: {
        id: video.plate.id,
        barcode: video.plate.barcode,
        name: video.plate.name
      },
      has_video_file: video.video_file.attached?,
      video_file_info: video.video_file.attached? ? {
        filename: video.video_file.filename.to_s,
        size: video.video_file.byte_size,
        content_type: video.video_file.content_type
      } : nil,
      dataset_count: video.calorimetry_datasets.count,
      created_at: video.created_at,
      updated_at: video.updated_at
    }
  end

  def format_calorimetry_video_detailed(video)
    base_data = format_calorimetry_video(video)

    base_data.merge({
      datasets: video.calorimetry_datasets.includes(:well).recent.map do |dataset|
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
