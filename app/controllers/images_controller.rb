class ImagesController < ApplicationController
  before_action :set_well
  before_action :set_image, only: [ :show, :edit, :update, :destroy ]

  # GET /wells/:well_id/images/new
  def new
    @image = @well.images.build
  end

  # POST /wells/:well_id/images
  def create
    Rails.logger.debug "Raw params: #{params[:image].inspect}"
    cleaned_params = image_params
    Rails.logger.debug "Cleaned params: #{cleaned_params.inspect}"

    @image = @well.images.build(cleaned_params)

    # Set captured_at to current time if not provided
    @image.captured_at ||= Time.current

    Rails.logger.debug "Image attributes before save: #{@image.attributes.inspect}"
    Rails.logger.debug "Image valid?: #{@image.valid?}"
    Rails.logger.debug "Image errors: #{@image.errors.full_messages}" unless @image.valid?

    respond_to do |format|
      if @image.save
        format.html { redirect_to @well.plate, notice: "Image was successfully created." }
        format.json { render json: @image, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /wells/:well_id/images/:id
  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @image.id,
          pixel_size_x_mm: @image.pixel_size_x_mm,
          pixel_size_y_mm: @image.pixel_size_y_mm,
          reference_x_mm: @image.reference_x_mm,
          reference_y_mm: @image.reference_y_mm,
          reference_z_mm: @image.reference_z_mm,
          pixel_width: @image.pixel_width,
          pixel_height: @image.pixel_height,
          physical_width_mm: @image.physical_width_mm,
          physical_height_mm: @image.physical_height_mm,
          bounding_box: @image.bounding_box,
          description: @image.description,
          captured_at: @image.captured_at,
          file_url: @image.file.attached? ? url_for(@image.file) : nil
        }
      end
    end
  end

  # GET /wells/:well_id/images/:id/edit
  def edit
  end

  # PATCH/PUT /wells/:well_id/images/:id
  def update
    respond_to do |format|
      if @image.update(image_params)
        format.html { redirect_to [ @well, @image ], notice: "Image was successfully updated." }
        format.json { render json: @image }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /wells/:well_id/images/:id
  def destroy
    @image.destroy!

    respond_to do |format|
      format.html { redirect_to @well, status: :see_other, notice: "Image was successfully deleted." }
      format.json { head :no_content }
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
    # Get permitted parameters
    permitted = params.require(:image).permit(
      :file, :pixel_size_x_mm, :pixel_size_y_mm,
      :reference_x_mm, :reference_y_mm, :reference_z_mm,
      :pixel_width, :pixel_height, :description, :captured_at
    )

    # Convert empty strings to nil for dimension fields so they can be auto-detected
    [ :pixel_width, :pixel_height ].each do |field|
      if permitted[field].is_a?(String) && permitted[field].strip.empty?
        permitted[field] = nil
      end
    end

    permitted
  end
end
