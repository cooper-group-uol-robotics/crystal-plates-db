class Api::V1::PxrdPatternsController < Api::V1::BaseController
  before_action :set_well, only: [ :index, :create ]
  before_action :set_pxrd_pattern, only: [ :show, :update, :destroy, :data ]

  # GET /api/v1/wells/:well_id/pxrd_patterns
  def index
    if params[:well_id]
      @pxrd_patterns = @well.pxrd_patterns.order(created_at: :desc)
    else
      @pxrd_patterns = PxrdPattern.includes(:well).order(created_at: :desc)
    end
    render json: @pxrd_patterns.map { |pattern| format_pxrd_pattern(pattern) }
  end

  # GET /api/v1/pxrd_patterns/:id
  def show
    render json: format_pxrd_pattern_detailed(@pxrd_pattern)
  end

  # GET /api/v1/pxrd_patterns/:id/data
  def data
    begin
      parsed_data = @pxrd_pattern.parse_xrdml_data
      render json: {
        data: {
          two_theta: parsed_data[:two_theta],
          intensities: parsed_data[:intensities],
          metadata: {
            title: @pxrd_pattern.title,
            measured_at: @pxrd_pattern.measured_at,
            total_points: parsed_data[:two_theta]&.length || 0
          }
        }
      }
    rescue => e
      render json: { error: "Failed to parse PXRD data: #{e.message}" }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/wells/:well_id/pxrd_patterns
  def create
    @pxrd_pattern = @well.pxrd_patterns.build(pxrd_pattern_params)

    if @pxrd_pattern.save
      render json: format_pxrd_pattern_detailed(@pxrd_pattern), status: :created
    else
      render json: {
        error: "Failed to create PXRD pattern",
        details: @pxrd_pattern.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/pxrd_patterns/:id
  def update
    if @pxrd_pattern.update(pxrd_pattern_params)
      render json: format_pxrd_pattern_detailed(@pxrd_pattern)
    else
      render json: {
        error: "Failed to update PXRD pattern",
        details: @pxrd_pattern.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/pxrd_patterns/:id
  def destroy
    @pxrd_pattern.destroy!
    render json: { message: "PXRD pattern successfully deleted" }
  end

  private

  def set_well
    @well = Well.find(params[:well_id])
  end

  def set_pxrd_pattern
    if params[:well_id]
      @pxrd_pattern = @well.pxrd_patterns.find(params[:id])
    else
      @pxrd_pattern = PxrdPattern.find(params[:id])
    end
  end

  def pxrd_pattern_params
    params.require(:pxrd_pattern).permit(:title, :pxrd_data_file)
  end

  def format_pxrd_pattern(pattern)
    {
      id: pattern.id,
      title: pattern.title,
      well_id: pattern.well_id,
      well_label: pattern.well.well_label_with_subwell,
      plate_barcode: pattern.well.plate.barcode,
      measured_at: pattern.measured_at,
      file_attached: pattern.pxrd_data_file.attached?,
      file_url: pattern.pxrd_data_file.attached? ? url_for(pattern.pxrd_data_file) : nil,
      file_size: pattern.pxrd_data_file.attached? ? pattern.pxrd_data_file.byte_size : nil,
      created_at: pattern.created_at,
      updated_at: pattern.updated_at
    }
  end

  def format_pxrd_pattern_detailed(pattern)
    base_data = format_pxrd_pattern(pattern)

    # Add detailed information
    base_data.merge({
      well: {
        id: pattern.well.id,
        label: pattern.well.well_label_with_subwell,
        row: pattern.well.well_row,
        column: pattern.well.well_column,
        subwell: pattern.well.subwell,
        plate: {
          id: pattern.well.plate.id,
          barcode: pattern.well.plate.barcode,
          name: pattern.well.plate.name
        }
      },
      file_metadata: pattern.pxrd_data_file.attached? ? {
        filename: pattern.pxrd_data_file.filename.to_s,
        content_type: pattern.pxrd_data_file.content_type,
        byte_size: pattern.pxrd_data_file.byte_size,
        created_at: pattern.pxrd_data_file.created_at
      } : nil
    })
  end
end
