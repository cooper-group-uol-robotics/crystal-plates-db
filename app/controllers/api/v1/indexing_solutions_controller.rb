class Api::V1::IndexingSolutionsController < Api::V1::BaseController
  before_action :set_scxrd_dataset
  before_action :set_indexing_solution, only: [:show, :destroy]

  # GET /api/v1/scxrd_datasets/:scxrd_dataset_id/indexing_solutions
  def index
    @indexing_solutions = @scxrd_dataset.indexing_solutions.ordered_by_quality
    
    render json: {
      scxrd_dataset_id: @scxrd_dataset.id,
      count: @indexing_solutions.count,
      active_solution_id: @scxrd_dataset.active_solution&.id,
      solutions: @indexing_solutions.map { |solution| solution_json(solution) }
    }
  end

  # GET /api/v1/scxrd_datasets/:scxrd_dataset_id/indexing_solutions/:id
  def show
    render json: {
      solution: detailed_solution_json(@indexing_solution)
    }
  end

  # POST /api/v1/scxrd_datasets/:scxrd_dataset_id/indexing_solutions
  def create
    @indexing_solution = @scxrd_dataset.indexing_solutions.build(indexing_solution_params)
    
    if @indexing_solution.save
      render json: {
        message: "Indexing solution created successfully",
        solution: detailed_solution_json(@indexing_solution)
      }, status: :created
    else
      render json: {
        error: "Failed to create indexing solution",
        errors: @indexing_solution.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/scxrd_datasets/:scxrd_dataset_id/indexing_solutions/:id
  def destroy
    @indexing_solution.destroy
    render json: {
      message: "Indexing solution deleted successfully"
    }
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

  def solution_json(solution)
    {
      id: solution.id,
      source: solution.source,
      created_at: solution.created_at,
      ub_matrix: solution.has_ub_matrix? ? {
        ub11: solution.ub11, ub12: solution.ub12, ub13: solution.ub13,
        ub21: solution.ub21, ub22: solution.ub22, ub23: solution.ub23,
        ub31: solution.ub31, ub32: solution.ub32, ub33: solution.ub33,
        wavelength: solution.wavelength
      } : nil,
      primitive_unit_cell: solution.has_primitive_cell? ? {
        a: solution.primitive_a,
        b: solution.primitive_b,
        c: solution.primitive_c,
        alpha: solution.primitive_alpha,
        beta: solution.primitive_beta,
        gamma: solution.primitive_gamma
      } : nil,
      conventional_unit_cell: solution.has_conventional_cell? ? {
        a: solution.conventional_a,
        b: solution.conventional_b,
        c: solution.conventional_c,
        alpha: solution.conventional_alpha,
        beta: solution.conventional_beta,
        gamma: solution.conventional_gamma,
        bravais: solution.conventional_bravais,
        cb_op: solution.conventional_cb_op,
        distance: solution.conventional_distance
      } : nil,
      spots_found: solution.spots_found,
      spots_indexed: solution.spots_indexed,
      indexing_rate: solution.indexing_rate,
      is_active: (@scxrd_dataset.active_solution&.id == solution.id)
    }
  end

  def detailed_solution_json(solution)
    solution_json(solution).merge({
      display_label: solution.display_label
    })
  end
end
