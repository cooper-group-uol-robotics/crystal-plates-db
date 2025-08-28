class PxrdPatternsController < ApplicationController
  before_action :set_well, except: [ :plot ]
  before_action :set_pxrd_pattern, only: [ :show, :edit, :update, :destroy ]

  # GET /wells/:well_id/pxrd_patterns
  def index
    @pxrd_patterns = @well.pxrd_patterns.order(created_at: :desc)
    render partial: "pxrd_patterns/gallery", locals: { well: @well }
  end

  # GET /pxrd_patterns/:id/plot
  def plot
    pattern = PxrdPattern.find(params[:id])
    render partial: "pxrd_patterns/plot", locals: { pxrd_pattern: pattern }
  end

  # GET /wells/:well_id/pxrd_patterns/new
  def new
    @pxrd_pattern = @well.pxrd_patterns.build
  end

  # POST /wells/:well_id/pxrd_patterns
  def create
    @pxrd_pattern = @well.pxrd_patterns.build(pxrd_pattern_params)

    respond_to do |format|
      if @pxrd_pattern.save
        format.html { redirect_to @well.plate, notice: "PXRD pattern was successfully uploaded." }
        format.json { render json: @pxrd_pattern, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @pxrd_pattern.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /wells/:well_id/pxrd_patterns/:id
  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @pxrd_pattern.id,
          title: @pxrd_pattern.title,
          file_url: @pxrd_pattern.xrdml_file.attached? ? url_for(@pxrd_pattern.xrdml_file) : nil,
          measured_at: @pxrd_pattern.measured_at,
          created_at: @pxrd_pattern.created_at
        }
      end
    end
  end

  # GET /wells/:well_id/pxrd_patterns/:id/edit
  def edit
  end

  # PATCH/PUT /wells/:well_id/pxrd_patterns/:id
  def update
    respond_to do |format|
      if @pxrd_pattern.update(pxrd_pattern_params)
        format.html { redirect_to [ @well, @pxrd_pattern ], notice: "PXRD pattern was successfully updated." }
        format.json { render json: @pxrd_pattern }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @pxrd_pattern.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /wells/:well_id/pxrd_patterns/:id
  def destroy
    @pxrd_pattern.destroy!
    respond_to do |format|
      format.html { redirect_to @well.plate, status: :see_other, notice: "PXRD pattern was successfully deleted." }
      format.json { head :no_content }
    end
  end

  private

  def set_well
    @well = Well.find(params[:well_id])
  end

  def set_pxrd_pattern
    @pxrd_pattern = @well.pxrd_patterns.find(params[:id])
  end

  def pxrd_pattern_params
    params.require(:pxrd_pattern).permit(:title, :xrdml_file)
  end
end
