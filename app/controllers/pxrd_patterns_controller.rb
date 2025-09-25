class PxrdPatternsController < ApplicationController
  before_action :set_well, only: [ :new, :create ], if: -> { params[:well_id].present? }
  before_action :set_pxrd_pattern, only: [ :show, :edit, :update, :destroy ]

  # GET /pxrd_patterns (standalone index for all patterns)
  def index
    if params[:well_id].present?
      # Well-specific index (existing functionality)
      @well = Well.find(params[:well_id])
      @pxrd_patterns = @well.pxrd_patterns.order(created_at: :desc)
      render partial: "pxrd_patterns/gallery", locals: { well: @well }
    else
      # Global index for all PXRD patterns
      @pxrd_patterns = PxrdPattern.includes(well: :plate)

      # Apply search filter if provided
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @pxrd_patterns = @pxrd_patterns.joins(:pxrd_data_file_attachment)
                                       .joins("JOIN active_storage_blobs ON active_storage_attachments.blob_id = active_storage_blobs.id")
                                       .where("LOWER(active_storage_blobs.filename) LIKE LOWER(?) OR LOWER(pxrd_patterns.title) LIKE LOWER(?)",
                                              search_term, search_term)
      end

      # Apply sorting
      sort_column = params[:sort] || "created_at"
      sort_direction = params[:direction] || "desc"

      case sort_column
      when "measured_at"
        # Sort by measured_at, falling back to created_at for patterns without measured_at
        if sort_direction == "asc"
          @pxrd_patterns = @pxrd_patterns.order(Arel.sql("COALESCE(pxrd_patterns.measured_at, pxrd_patterns.created_at) ASC"))
        else
          @pxrd_patterns = @pxrd_patterns.order(Arel.sql("COALESCE(pxrd_patterns.measured_at, pxrd_patterns.created_at) DESC"))
        end
      when "title"
        @pxrd_patterns = @pxrd_patterns.order("pxrd_patterns.title #{sort_direction == 'desc' ? 'DESC' : 'ASC'}")
      when "filename"
        # Ensure we have the joins for filename sorting even if search didn't add them
        unless @pxrd_patterns.joins_values.any? { |join| join.to_s.include?("active_storage_attachments") }
          @pxrd_patterns = @pxrd_patterns.joins(:pxrd_data_file_attachment)
                                         .joins("JOIN active_storage_blobs ON active_storage_attachments.blob_id = active_storage_blobs.id")
        end
        @pxrd_patterns = @pxrd_patterns.order("active_storage_blobs.filename #{sort_direction == 'desc' ? 'DESC' : 'ASC'}")
      else
        @pxrd_patterns = @pxrd_patterns.order("pxrd_patterns.created_at #{sort_direction == 'desc' ? 'DESC' : 'ASC'}")
      end

      @pxrd_patterns = @pxrd_patterns.page(params[:page]).per(20)
      render "index"
    end
  end

  # GET /pxrd_patterns/:id/plot
  def plot
    pattern = PxrdPattern.find(params[:id])
    render partial: "pxrd_patterns/plot", locals: { pxrd_pattern: pattern }
  end

  # GET /wells/:well_id/pxrd_patterns/new or GET /pxrd_patterns/new
  def new
    if params[:well_id].present?
      set_well unless @well
      @pxrd_pattern = @well.pxrd_patterns.build
    else
      @pxrd_pattern = PxrdPattern.new
    end
  end

  # POST /wells/:well_id/pxrd_patterns or POST /pxrd_patterns
  def create
    if params[:well_id].present?
      set_well unless @well
      @pxrd_pattern = @well.pxrd_patterns.build(pxrd_pattern_params)
      success_redirect = @well.plate
    else
      @pxrd_pattern = PxrdPattern.new(pxrd_pattern_params)
      success_redirect = @pxrd_pattern
    end

    respond_to do |format|
      if @pxrd_pattern.save
        format.html { redirect_to success_redirect, notice: "PXRD pattern was successfully uploaded." }
        format.json { render json: @pxrd_pattern, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @pxrd_pattern.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /wells/:well_id/pxrd_patterns/:id or GET /pxrd_patterns/:id
  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @pxrd_pattern.id,
          title: @pxrd_pattern.title,
          file_url: @pxrd_pattern.pxrd_data_file.attached? ? url_for(@pxrd_pattern.pxrd_data_file) : nil,
          measured_at: @pxrd_pattern.measured_at,
          created_at: @pxrd_pattern.created_at
        }
      end
    end
  end

  # GET /wells/:well_id/pxrd_patterns/:id/edit or GET /pxrd_patterns/:id/edit
  def edit
  end

  # PATCH/PUT /wells/:well_id/pxrd_patterns/:id or PATCH/PUT /pxrd_patterns/:id
  def update
    respond_to do |format|
      if @pxrd_pattern.update(pxrd_pattern_params)
        success_redirect = @pxrd_pattern.well.present? ? [ @pxrd_pattern.well, @pxrd_pattern ] : @pxrd_pattern
        format.html { redirect_to success_redirect, notice: "PXRD pattern was successfully updated." }
        format.json { render json: @pxrd_pattern }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @pxrd_pattern.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /wells/:well_id/pxrd_patterns/:id or DELETE /pxrd_patterns/:id
  def destroy
    # Store redirect path before destroying the pattern
    success_redirect = @pxrd_pattern.well.present? ? @pxrd_pattern.well.plate : pxrd_patterns_path

    @pxrd_pattern.destroy!
    respond_to do |format|
      format.html { redirect_to success_redirect, status: :see_other, notice: "PXRD pattern was successfully deleted." }
      format.json { head :no_content }
    end
  end

  private

  def set_well
    @well = Well.find(params[:well_id])
  end

  def set_pxrd_pattern
    if params[:well_id].present?
      set_well
      @pxrd_pattern = @well.pxrd_patterns.find(params[:id])
    else
      @pxrd_pattern = PxrdPattern.find(params[:id])
    end
  end

  def pxrd_pattern_params
    params.require(:pxrd_pattern).permit(:title, :pxrd_data_file)
  end
end
