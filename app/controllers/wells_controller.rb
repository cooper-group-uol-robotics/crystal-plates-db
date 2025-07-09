class WellsController < ApplicationController
  before_action :set_well, only: %i[ show edit update destroy ]

  # GET /wells or /wells.json
  def index
    @wells = Well.all
  end

  # GET /wells/1 or /wells/1.json
  def show
  end

  # GET /wells/new
  def new
    @well = Well.new
  end

  # GET /wells/1/edit
  def edit
  end

  # POST /wells or /wells.json
  def create
    @well = Well.new(well_params)

    respond_to do |format|
      if @well.save
        format.html { redirect_to @well, notice: "Well was successfully created." }
        format.json { render :show, status: :created, location: @well }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @well.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /wells/1 or /wells/1.json
  def update
    respond_to do |format|
      if @well.update(well_params)
        format.html { redirect_to @well, notice: "Well was successfully updated." }
        format.json { render :show, status: :ok, location: @well }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @well.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /wells/1 or /wells/1.json
  def destroy
    @well.destroy!

    respond_to do |format|
      format.html { redirect_to wells_path, status: :see_other, notice: "Well was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def images
    @well = Well.find(params[:id])
    render partial: 'images', locals: { well: @well }
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_well
      @well = Well.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def well_params
      params.require(:well).permit(:plate_id, :well_row, :well_column, :subwell)
    end


end
