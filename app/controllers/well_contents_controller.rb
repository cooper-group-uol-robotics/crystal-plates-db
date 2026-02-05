class WellContentsController < ApplicationController
  before_action :set_well
  before_action :set_well_content, only: [ :update, :destroy ]

  # POST /wells/:well_id/well_contents
  def create
    @well_content = @well.well_contents.build(well_content_params)

    # Handle polymorphic content assignment
    if params[:well_content][:contentable_type].present? && params[:well_content][:contentable_id].present?
      # New polymorphic approach
      contentable_class = params[:well_content][:contentable_type].constantize
      @well_content.contentable = contentable_class.find(params[:well_content][:contentable_id])
    elsif params[:well_content][:stock_solution_id].present?
      # Backward compatibility
      @well_content.contentable = StockSolution.find(params[:well_content][:stock_solution_id])
    elsif params[:well_content][:chemical_id].present?
      # Backward compatibility
      @well_content.contentable = Chemical.find(params[:well_content][:chemical_id])
    end

    if @well_content.save
      content_type = @well_content.stock_solution? ? "Stock solution" : "Chemical"
      render json: {
        status: "success",
        message: "#{content_type} added successfully",
        well_content: @well_content
      }, status: :created
    else
      render json: {
        status: "error",
        message: @well_content.errors.full_messages.join(", "),
        errors: @well_content.errors
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /wells/:well_id/well_contents/:id
  def update
    # Handle polymorphic content assignment
    if params[:well_content][:contentable_type].present? && params[:well_content][:contentable_id].present?
      # New polymorphic approach
      contentable_class = params[:well_content][:contentable_type].constantize
      @well_content.contentable = contentable_class.find(params[:well_content][:contentable_id])
    elsif params[:well_content][:stock_solution_id].present?
      # Backward compatibility
      @well_content.contentable = StockSolution.find(params[:well_content][:stock_solution_id])
    elsif params[:well_content][:chemical_id].present?
      # Backward compatibility
      @well_content.contentable = Chemical.find(params[:well_content][:chemical_id])
    end

    if @well_content.update(well_content_params)
      content_type = @well_content.stock_solution? ? "Stock solution" : "Chemical"
      render json: {
        status: "success",
        message: "#{content_type} updated successfully",
        well_content: @well_content
      }
    else
      render json: {
        status: "error",
        message: @well_content.errors.full_messages.join(", "),
        errors: @well_content.errors
      }, status: :unprocessable_entity
    end
  end

  # DELETE /wells/:well_id/well_contents/:id
  def destroy
    content_type = @well_content.stock_solution? ? "Stock solution" : "Chemical"
    @well_content.destroy
    render json: {
      status: "success",
      message: "#{content_type} removed successfully"
    }
  end

  # DELETE /wells/:well_id/well_contents/destroy_all
  def destroy_all
    @well.well_contents.destroy_all
    render json: {
      status: "success",
      message: "All well contents removed successfully"
    }
  end

  private

  def set_well
    @well = Well.find(params[:well_id])
  end

  def set_well_content
    @well_content = @well.well_contents.find(params[:id])
  end

  def well_content_params
    params.require(:well_content).permit(:stock_solution_id, :chemical_id, :contentable_type, :contentable_id, :amount_with_unit, :notes)
  end
end
