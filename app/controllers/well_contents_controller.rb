class WellContentsController < ApplicationController
  before_action :set_well
  before_action :set_well_content, only: [ :update, :destroy ]

  # POST /wells/:well_id/well_contents
  def create
    @well_content = @well.well_contents.build(well_content_params)

    if @well_content.save
      render json: {
        status: "success",
        message: "Stock solution added successfully",
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
    if @well_content.update(well_content_params)
      render json: {
        status: "success",
        message: "Stock solution updated successfully",
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
    @well_content.destroy
    render json: {
      status: "success",
      message: "Stock solution removed successfully"
    }
  end

  # DELETE /wells/:well_id/well_contents/destroy_all
  def destroy_all
    @well.well_contents.destroy_all
    render json: {
      status: "success",
      message: "All stock solutions removed successfully"
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
    params.require(:well_content).permit(:stock_solution_id, :volume_with_unit, :notes)
  end
end
