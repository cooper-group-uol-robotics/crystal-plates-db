class DiffractionImagesController < ApplicationController
  before_action :set_scxrd_dataset
  before_action :set_diffraction_image, only: [:show, :image_data, :download]

  def index
    @diffraction_images = @scxrd_dataset.diffraction_images.ordered
    @runs = @diffraction_images.group_by(&:run_number)
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          success: true,
          diffraction_images: @diffraction_images.map do |image|
            {
              id: image.id,
              run_number: image.run_number,
              image_number: image.image_number,
              filename: image.filename,
              file_size: image.file_size,
              file_size_human: image.file_size_human,
              display_name: image.display_name,
              sequence_position: image.sequence_position
            }
          end,
          runs: @runs.keys.sort,
          total_count: @diffraction_images.count
        }
      end
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          success: true,
          diffraction_image: {
            id: @diffraction_image.id,
            run_number: @diffraction_image.run_number,
            image_number: @diffraction_image.image_number,
            filename: @diffraction_image.filename,
            file_size: @diffraction_image.file_size,
            file_size_human: @diffraction_image.file_size_human,
            display_name: @diffraction_image.display_name,
            sequence_position: @diffraction_image.sequence_position,
            next_image_id: @diffraction_image.next_image&.id,
            previous_image_id: @diffraction_image.previous_image&.id
          }
        }
      end
    end
  end

  def image_data
    return render_error("No rodhypix file attached") unless @diffraction_image.rodhypix_file.attached?

    begin
      # Parse the diffraction image data using the dataset's parsing method
      parsed_data = @scxrd_dataset.parsed_image_data(diffraction_image: @diffraction_image)
      
      if parsed_data[:success]
        render json: {
          success: true,
          image_data: parsed_data[:image_data],
          dimensions: parsed_data[:dimensions],
          pixel_size: parsed_data[:pixel_size],
          metadata: parsed_data[:metadata].merge({
            run_number: @diffraction_image.run_number,
            image_number: @diffraction_image.image_number,
            filename: @diffraction_image.filename
          })
        }
      else
        render_error(parsed_data[:error])
      end
    rescue => e
      Rails.logger.error "Error parsing diffraction image #{@diffraction_image.id}: #{e.message}"
      render_error("Failed to parse diffraction image: #{e.message}")
    end
  end

  def download
    return render_error("No rodhypix file attached") unless @diffraction_image.rodhypix_file.attached?
    
    redirect_to rails_blob_path(@diffraction_image.rodhypix_file, disposition: "attachment")
  end

  private

  def set_scxrd_dataset
    if params[:well_id]
      @well = Well.find(params[:well_id])
      @scxrd_dataset = @well.scxrd_datasets.find(params[:scxrd_dataset_id])
    else
      @scxrd_dataset = ScxrdDataset.find(params[:scxrd_dataset_id])
    end
  rescue ActiveRecord::RecordNotFound
    render_error("SCXRD dataset not found", :not_found)
  end

  def set_diffraction_image
    @diffraction_image = @scxrd_dataset.diffraction_images.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Diffraction image not found", :not_found)
  end

  def render_error(message, status = :unprocessable_entity)
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: message) }
      format.json { render json: { success: false, error: message }, status: status }
    end
  end
end
