class StockSolutionsController < ApplicationController
  before_action :set_stock_solution, only: [ :show, :edit, :update, :destroy ]

  # GET /stock_solutions
  def index
    @stock_solutions = StockSolution.includes(:stock_solution_components, :chemicals)

    if params[:search].present?
      @stock_solutions = @stock_solutions.by_name(params[:search])
    end

    @stock_solutions = @stock_solutions.order(:name)
  end

  # GET /stock_solutions/1
  def show
    @stock_solution_components = @stock_solution.stock_solution_components
                                                .includes(:chemical, :unit)
                                                .ordered_by_chemical_name
  end

  # GET /stock_solutions/new
  def new
    @stock_solution = StockSolution.new
    @stock_solution.stock_solution_components.build
  end

  # GET /stock_solutions/1/edit
  def edit
  end

  # POST /stock_solutions
  def create
    @stock_solution = StockSolution.new(stock_solution_params)

    if @stock_solution.save
      redirect_to @stock_solution, notice: "Stock solution was successfully created."
    else
      # Ensure at least one component field is shown for re-rendering
      @stock_solution.stock_solution_components.build if @stock_solution.stock_solution_components.empty?
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /stock_solutions/1
  def update
    if @stock_solution.update(stock_solution_params)
      redirect_to @stock_solution, notice: "Stock solution was successfully updated."
    else
      # Ensure at least one component field is shown for re-rendering
      @stock_solution.stock_solution_components.build if @stock_solution.stock_solution_components.empty?
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /stock_solutions/1
  def destroy
    unless @stock_solution.can_be_deleted?
      redirect_to @stock_solution, alert: "Cannot delete stock solution that is used in wells."
      return
    end

    @stock_solution.destroy
    redirect_to stock_solutions_url, notice: "Stock solution was successfully deleted."
  end

  # GET /stock_solutions/search
  def search
    query = params[:q]

    if query.present?
      @stock_solutions = StockSolution.includes(:stock_solution_components, :chemicals)
                                     .by_name(query)
                                     .order(:name)
                                     .limit(10)

      render json: @stock_solutions.map { |ss|
        {
          id: ss.id,
          display_name: ss.display_name,
          component_summary: ss.stock_solution_components.any? ? ss.component_summary : nil
        }
      }
    else
      render json: []
    end
  end

  private

  def set_stock_solution
    @stock_solution = StockSolution.find(params[:id])
  end

  def stock_solution_params
    params.require(:stock_solution).permit(:name,
      stock_solution_components_attributes: [ :id, :chemical_id, :amount, :unit_id, :amount_with_unit, :_destroy ])
  end
end
