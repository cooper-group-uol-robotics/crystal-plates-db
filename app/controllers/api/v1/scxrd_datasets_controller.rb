class Api::V1::ScxrdDatasetsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  before_action :set_well
  before_action :set_scxrd_dataset, only: [:show, :update, :destroy]
  
  # GET /api/v1/wells/:well_id/scxrd_datasets
  def index
    @scxrd_datasets = @well.scxrd_datasets.includes(:lattice_centring).order(created_at: :desc)
    
    render json: {
      well_id: @well.id,
      well_label: @well.well_label,
      count: @scxrd_datasets.count,
      scxrd_datasets: @scxrd_datasets.map { |dataset| dataset_json(dataset) }
    }
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/:id
  def show
    render json: {
      scxrd_dataset: detailed_dataset_json(@scxrd_dataset)
    }
  end

  # POST /api/v1/wells/:well_id/scxrd_datasets
  def create
    @scxrd_dataset = @well.scxrd_datasets.build(scxrd_dataset_params)
    @scxrd_dataset.date_uploaded = Time.current

    if @scxrd_dataset.save
      render json: {
        message: "SCXRD dataset created successfully",
        scxrd_dataset: detailed_dataset_json(@scxrd_dataset)
      }, status: :created
    else
      render json: {
        error: "Failed to create SCXRD dataset",
        errors: @scxrd_dataset.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /api/v1/wells/:well_id/scxrd_datasets/:id
  def update
    if @scxrd_dataset.update(scxrd_dataset_params)
      render json: {
        message: "SCXRD dataset updated successfully",
        scxrd_dataset: detailed_dataset_json(@scxrd_dataset)
      }
    else
      render json: {
        error: "Failed to update SCXRD dataset",
        errors: @scxrd_dataset.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/wells/:well_id/scxrd_datasets/:id
  def destroy
    @scxrd_dataset.destroy
    render json: {
      message: "SCXRD dataset deleted successfully"
    }
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/:id/image_data
  def image_data
    unless @scxrd_dataset.has_first_image?
      render json: { error: "No diffraction image available" }, status: :not_found
      return
    end

    parsed_data = @scxrd_dataset.parsed_image_data
    
    if parsed_data[:success]
      render json: {
        success: true,
        dimensions: parsed_data[:dimensions],
        pixel_size: parsed_data[:pixel_size],
        metadata: parsed_data[:metadata],
        image_data: parsed_data[:image_data]
      }
    else
      render json: {
        success: false,
        error: parsed_data[:error]
      }, status: :unprocessable_entity
    end
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/correlations
  def spatial_correlations
    tolerance_mm = params[:tolerance_mm]&.to_f || 0.5
    correlations = ScxrdDataset.spatial_correlations_for_well(@well, tolerance_mm)
    
    render json: {
      well_id: @well.id,
      well_label: @well.well_label,
      tolerance_mm: tolerance_mm,
      correlations_count: correlations.count,
      correlations: correlations.map do |corr|
        {
          scxrd_dataset: dataset_json(corr[:scxrd_dataset]),
          point_of_interests: corr[:distances].map do |dist_info|
            poi = dist_info[:poi]
            coords = poi.real_world_coordinates
            {
              id: poi.id,
              point_type: poi.point_type,
              pixel_coordinates: { x: poi.pixel_x, y: poi.pixel_y },
              real_world_coordinates: coords,
              distance_mm: dist_info[:distance_mm]&.round(3),
              image_id: poi.image_id,
              marked_at: poi.marked_at
            }
          end
        }
      end
    }
  end

  # GET /api/v1/wells/:well_id/scxrd_datasets/search
  def search
    datasets = @well.scxrd_datasets.includes(:lattice_centring)
    
    # Filter by experiment name
    if params[:experiment_name].present?
      datasets = datasets.where("experiment_name ILIKE ?", "%#{params[:experiment_name]}%")
    end
    
    # Filter by date range
    if params[:date_from].present?
      datasets = datasets.where("date_measured >= ?", Date.parse(params[:date_from]))
    end
    
    if params[:date_to].present?
      datasets = datasets.where("date_measured <= ?", Date.parse(params[:date_to]))
    end
    
    # Filter by lattice centering
    if params[:lattice_centring].present?
      datasets = datasets.joins(:lattice_centring)
                        .where(lattice_centrings: { symbol: params[:lattice_centring] })
    end
    
    # Filter by coordinate proximity
    if params[:near_x].present? && params[:near_y].present?
      tolerance = params[:tolerance_mm]&.to_f || 1.0
      datasets = datasets.near_coordinates(
        params[:near_x].to_f, 
        params[:near_y].to_f, 
        tolerance
      )
    end
    
    # Filter by unit cell parameters (with tolerance)
    if params[:unit_cell].present?
      cell_params = params[:unit_cell]
      tolerance_percent = params[:cell_tolerance_percent]&.to_f || 5.0
      
      %w[a b c alpha beta gamma].each do |param|
        if cell_params[param].present?
          value = cell_params[param].to_f
          tolerance_abs = value * (tolerance_percent / 100.0)
          datasets = datasets.where(
            "#{param} BETWEEN ? AND ?", 
            value - tolerance_abs, 
            value + tolerance_abs
          )
        end
      end
    end
    
    datasets = datasets.order(created_at: :desc).limit(100)
    
    render json: {
      well_id: @well.id,
      search_params: params.except(:controller, :action, :well_id),
      results_count: datasets.count,
      scxrd_datasets: datasets.map { |dataset| dataset_json(dataset) }
    }
  end

  private

  def set_well
    @well = Well.find(params[:well_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Well not found" }, status: :not_found
  end

  def set_scxrd_dataset
    @scxrd_dataset = @well.scxrd_datasets.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "SCXRD dataset not found" }, status: :not_found
  end

  def scxrd_dataset_params
    params.require(:scxrd_dataset).permit(
      :experiment_name, :date_measured, :lattice_centring_id,
      :real_world_x_mm, :real_world_y_mm, :real_world_z_mm,
      :a, :b, :c, :alpha, :beta, :gamma
    )
  end

  def dataset_json(dataset)
    {
      id: dataset.id,
      experiment_name: dataset.experiment_name,
      date_measured: dataset.date_measured&.strftime("%Y-%m-%d"),
      date_uploaded: dataset.date_uploaded&.strftime("%Y-%m-%d %H:%M:%S"),
      lattice_centring: dataset.lattice_centring&.symbol,
      real_world_coordinates: (dataset.real_world_x_mm || dataset.real_world_y_mm || dataset.real_world_z_mm) ? {
        x_mm: dataset.real_world_x_mm,
        y_mm: dataset.real_world_y_mm,
        z_mm: dataset.real_world_z_mm
      } : nil,
      unit_cell: dataset.a.present? ? {
        a: number_with_precision(dataset.a, precision: 3),
        b: number_with_precision(dataset.b, precision: 3),
        c: number_with_precision(dataset.c, precision: 3),
        alpha: number_with_precision(dataset.alpha, precision: 1),
        beta: number_with_precision(dataset.beta, precision: 1),
        gamma: number_with_precision(dataset.gamma, precision: 1)
      } : nil,
      has_archive: dataset.archive.attached?,
      has_peak_table: dataset.has_peak_table?,
      has_first_image: dataset.has_first_image?,
      created_at: dataset.created_at,
      updated_at: dataset.updated_at
    }
  end

  def detailed_dataset_json(dataset)
    base_json = dataset_json(dataset)
    base_json.merge({
      peak_table_size: dataset.has_peak_table? ? number_to_human_size(dataset.peak_table_size) : nil,
      first_image_size: dataset.has_first_image? ? number_to_human_size(dataset.first_image_size) : nil,
      image_metadata: dataset.has_first_image? ? dataset.image_metadata : nil,
      nearby_point_of_interests: dataset.has_real_world_coordinates? ? 
        dataset.nearby_point_of_interests.map do |poi|
          coords = poi.real_world_coordinates
          {
            id: poi.id,
            point_type: poi.point_type,
            pixel_coordinates: { x: poi.pixel_x, y: poi.pixel_y },
            real_world_coordinates: coords,
            distance_mm: dataset.distance_to_coordinates(coords[:x_mm], coords[:y_mm], coords[:z_mm])&.round(3),
            image_id: poi.image_id
          }
        end : []
    })
  end
end