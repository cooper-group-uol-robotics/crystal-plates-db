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
      render :new
    end
  end

  # PATCH/PUT /stock_solutions/1
  def update
    if @stock_solution.update(stock_solution_params)
      redirect_to @stock_solution, notice: "Stock solution was successfully updated."
    else
      render :edit
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

  private

  def set_stock_solution
    @stock_solution = StockSolution.find(params[:id])
  end

  def stock_solution_params
    params.require(:stock_solution).permit(:name,
      stock_solution_components_attributes: [ :id, :chemical_id, :amount, :unit_id, :amount_with_unit, :_destroy ])
  end
end
