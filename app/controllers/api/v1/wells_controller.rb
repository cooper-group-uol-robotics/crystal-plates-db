module Api::V1
  class WellsController < BaseController
    before_action :set_well, only: [ :show, :update, :destroy ]
    before_action :set_plate, only: [ :index, :create ]

    # GET /api/v1/wells
    # GET /api/v1/plates/:barcode/wells
    def index
      wells = @plate ? @plate.wells : Well.includes(:plate)
      wells = wells.includes(:well_contents, :images)

      render_success(wells.map { |well| well_json(well) })
    end

    # GET /api/v1/wells/:id
    def show
      @well = Well.includes(:well_contents, :images).find(params[:id])
      render_success(well_json(@well, include_details: true))
    end

    # POST /api/v1/wells
    # POST /api/v1/plates/:barcode/wells
    def create
      well = @plate ? @plate.wells.build(well_params) : Well.new(well_params)

      if well.save
        render_success(well_json(well, include_details: true), status: :created, message: "Well created successfully")
      else
        render_error("Failed to create well", details: well.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # PUT/PATCH /api/v1/wells/:id
    def update
      if @well.update(well_params)
        render_success(well_json(@well, include_details: true), message: "Well updated successfully")
      else
        render_error("Failed to update well", details: @well.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # DELETE /api/v1/wells/:id
    def destroy
      if @well.destroy
        render_success(nil, message: "Well deleted successfully")
      else
        render_error("Failed to delete well", details: @well.errors.full_messages, status: :unprocessable_entity)
      end
    end

    private

    def set_well
      @well = Well.find(params[:id])
    end

    def set_plate
      @plate = Plate.find_by(barcode: params[:plate_barcode]) if params[:plate_barcode]
    end

    def well_params
      params.require(:well).permit(:plate_id, :well_row, :well_column)
    end

    def well_json(well, include_details: false)
      result = {
        id: well.id,
        well_row: well.well_row,
        well_column: well.well_column,
        position: well.well_label,
        plate_barcode: well.plate.barcode
      }

      if include_details
        result.merge!({
          well_contents: well.well_contents.map do |content|
            {
              id: content.id,
              stock_solution: content.stock_solution&.display_name,
              volume: content.display_volume
            }
          end,
          images: well.images.recent.map do |image|
            {
              id: image.id,
              pixel_size_x_mm: image.pixel_size_x_mm,
              pixel_size_y_mm: image.pixel_size_y_mm,
              captured_at: image.captured_at,
              description: image.description,
              file_url: image.file.attached? ? url_for(image.file) : nil
            }
          end,
          created_at: well.created_at,
          updated_at: well.updated_at
        })
      else
        result[:contents_count] = well.well_contents.count
        result[:images_count] = well.images.count
      end

      result
    end
  end
end
