module Api::V1
  class ImagesController < BaseController
    before_action :set_well, except: [:upload_to_well]
    before_action :set_image, only: [ :show, :update, :destroy ]

    # GET /api/v1/wells/:well_id/images
    def index
      images = @well.images.recent
      render_success(images.map { |image| image_json(image) })
    end

    # GET /api/v1/wells/:well_id/images/:id
    def show
      render_success(image_json(@image, include_details: true))
    end

    # POST /api/v1/wells/:well_id/images
    def create
      @image = @well.images.build(image_params)
      @image.captured_at ||= Time.current

      if @image.save
        render_success(image_json(@image, include_details: true), status: :created, message: "Image created successfully")
      else
        render_error("Failed to create image", details: @image.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # PUT/PATCH /api/v1/wells/:well_id/images/:id
    def update
      if @image.update(image_params)
        render_success(image_json(@image, include_details: true), message: "Image updated successfully")
      else
        render_error("Failed to update image", details: @image.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # DELETE /api/v1/wells/:well_id/images/:id
    def destroy
      if @image.destroy
        render_success(nil, message: "Image deleted successfully")
      else
        render_error("Failed to delete image", details: @image.errors.full_messages, status: :unprocessable_entity)
      end
    end

    # POST /api/v1/images/plate/:barcode/well/:well_string
    def upload_to_well
      @plate = Plate.find_by(barcode: params[:barcode])
      unless @plate
        render_error(
          "Plate not found", 
          details: ["No plate found with barcode '#{params[:barcode]}'"], 
          status: :not_found
        )
        return
      end

      @well = @plate.find_well_by_identifier(params[:well_string])
      unless @well
        render_error(
          "Well not found", 
          details: ["No well found with identifier '#{params[:well_string]}' on plate '#{params[:barcode]}'"], 
          status: :not_found
        )
        return
      end

      @image = @well.images.build(image_params)
      @image.captured_at ||= Time.current

      if @image.save
        render_success(image_json(@image, include_details: true), status: :created, message: "Image uploaded successfully")
      else
        render_error("Failed to create image", details: @image.errors.full_messages, status: :unprocessable_entity)
      end
    end

    private

    def set_well
      @well = Well.find(params[:well_id])
    end

    def set_image
      @image = @well.images.find(params[:id])
    end

    def image_params
      params.require(:image).permit(
        :file, :pixel_size_x_mm, :pixel_size_y_mm,
        :reference_x_mm, :reference_y_mm, :reference_z_mm,
        :pixel_width, :pixel_height, :description, :captured_at
      )
    end

    def image_json(image, include_details: false)
      result = {
        id: image.id,
        pixel_size_x_mm: image.pixel_size_x_mm,
        pixel_size_y_mm: image.pixel_size_y_mm,
        reference_x_mm: image.reference_x_mm,
        reference_y_mm: image.reference_y_mm,
        reference_z_mm: image.reference_z_mm,
        captured_at: image.captured_at,
        description: image.description
      }

      if include_details
        result.merge!({
          pixel_width: image.pixel_width,
          pixel_height: image.pixel_height,
          physical_width_mm: image.physical_width_mm,
          physical_height_mm: image.physical_height_mm,
          bounding_box: image.bounding_box,
          file_url: image.file.attached? ? url_for(image.file) : nil,
          file_size: image.file.attached? ? image.file.byte_size : nil,
          file_content_type: image.file.attached? ? image.file.content_type : nil,
          created_at: image.created_at,
          updated_at: image.updated_at
        })
      end

      result
    end
  end
end
