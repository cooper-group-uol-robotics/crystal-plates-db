class IndexingSolutionsController < ApplicationController
  before_action :set_scxrd_dataset
  before_action :set_indexing_solution, only: [:show, :destroy]

  # GET /scxrd_datasets/:scxrd_dataset_id/indexing_solutions
  def index
    @indexing_solutions = @scxrd_dataset.indexing_solutions.ordered_by_quality
    
    respond_to do |format|
      format.html
      format.json { render json: @indexing_solutions }
    end
  end

  # GET /scxrd_datasets/:scxrd_dataset_id/indexing_solutions/:id
  def show
    respond_to do |format|
      format.html
      format.json { render json: @indexing_solution }
    end
  end

  # POST /scxrd_datasets/:scxrd_dataset_id/indexing_solutions
  def create
    @indexing_solution = @scxrd_dataset.indexing_solutions.build(indexing_solution_params)
    
    if @indexing_solution.save
      redirect_to scxrd_dataset_indexing_solution_path(@scxrd_dataset, @indexing_solution),
                  notice: "Indexing solution created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /scxrd_datasets/:scxrd_dataset_id/indexing_solutions/:id
  def destroy
    @indexing_solution.destroy
    redirect_to scxrd_dataset_indexing_solutions_path(@scxrd_dataset),
                notice: "Indexing solution deleted successfully."
  end

  private

  def set_scxrd_dataset
    @scxrd_dataset = ScxrdDataset.find(params[:scxrd_dataset_id])
  end

  def set_indexing_solution
    @indexing_solution = @scxrd_dataset.indexing_solutions.find(params[:id])
  end

  def indexing_solution_params
    params.require(:indexing_solution).permit(
      :ub11, :ub12, :ub13, :ub21, :ub22, :ub23, :ub31, :ub32, :ub33, :wavelength,
      :primitive_a, :primitive_b, :primitive_c, :primitive_alpha, :primitive_beta, :primitive_gamma,
      :conventional_a, :conventional_b, :conventional_c, :conventional_alpha, :conventional_beta, :conventional_gamma,
      :conventional_bravais, :conventional_cb_op, :conventional_distance,
      :spots_found, :spots_indexed, :source
    )
  end
end
