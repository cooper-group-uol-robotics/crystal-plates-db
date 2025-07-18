class Api::V1::StockSolutionsController < Api::V1::BaseController
  before_action :set_stock_solution, only: [ :show, :update, :destroy ]

  # GET /api/v1/stock_solutions
  def index
    @stock_solutions = StockSolution.includes(:stock_solution_components, :chemicals)

    if params[:search].present?
      @stock_solutions = @stock_solutions.by_name(params[:search])
    end

    @stock_solutions = @stock_solutions.order(:name)

    render json: @stock_solutions.map { |ss| stock_solution_json(ss) }
  end

  # GET /api/v1/stock_solutions/1
  def show
    render json: stock_solution_json(@stock_solution, include_components: true)
  end

  # POST /api/v1/stock_solutions
  def create
    @stock_solution = StockSolution.new(stock_solution_params)

    if @stock_solution.save
      render json: stock_solution_json(@stock_solution, include_components: true), status: :created
    else
      render json: { errors: @stock_solution.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/stock_solutions/1
  def update
    if @stock_solution.update(stock_solution_params)
      render json: stock_solution_json(@stock_solution, include_components: true)
    else
      render json: { errors: @stock_solution.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/stock_solutions/1
  def destroy
    unless @stock_solution.can_be_deleted?
      render json: { error: "Cannot delete stock solution that is used in wells" }, status: :unprocessable_entity
      return
    end

    @stock_solution.destroy
    head :no_content
  end

  private

  def set_stock_solution
    @stock_solution = StockSolution.find(params[:id])
  end

  def stock_solution_params
    params.require(:stock_solution).permit(:name,
      stock_solution_components_attributes: [ :id, :chemical_id, :amount, :unit_id, :_destroy ])
  end

  def stock_solution_json(stock_solution, include_components: false)
    data = {
      id: stock_solution.id,
      name: stock_solution.name,
      display_name: stock_solution.display_name,
      total_components: stock_solution.total_components,
      used_in_wells_count: stock_solution.used_in_wells_count,
      can_be_deleted: stock_solution.can_be_deleted?,
      created_at: stock_solution.created_at,
      updated_at: stock_solution.updated_at
    }

    if include_components
      data[:components] = stock_solution.stock_solution_components.includes(:chemical, :unit).map do |component|
        {
          id: component.id,
          chemical: {
            id: component.chemical.id,
            name: component.chemical.name
          },
          amount: component.amount,
          unit: {
            id: component.unit.id,
            name: component.unit.name,
            symbol: component.unit.symbol
          },
          display_amount: component.display_amount,
          formatted_component: component.formatted_component
        }
      end
    end

    data
  end
end
