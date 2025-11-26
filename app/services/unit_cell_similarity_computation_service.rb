class UnitCellSimilarityComputationService < ApplicationJob
  queue_as :default

  # Compute similarities for a new dataset against all existing datasets
  def perform(target_dataset)
    return unless target_dataset.has_primitive_cell?
    return unless G6DistanceService.enabled?

    Rails.logger.info "Computing unit cell similarities for dataset #{target_dataset.id}"

    # Get all other datasets with primitive cells
    other_datasets = ScxrdDataset.with_primitive_cells.where.not(id: target_dataset.id)
    
    if other_datasets.empty?
      Rails.logger.info "No other datasets to compare with"
      return
    end

    # Remove existing similarities for this dataset to avoid duplicates
    UnitCellSimilarity.for_dataset(target_dataset.id).destroy_all

    # Prepare comparison data for API call
    reference_cell = G6DistanceService.send(:extract_cell_params, target_dataset)
    comparison_cells_with_ids = other_datasets.map do |dataset|
      {
        dataset_id: dataset.id,
        cell_params: G6DistanceService.send(:extract_cell_params, dataset)
      }
    end

    # Calculate distances using the existing G6DistanceService
    distances_hash = G6DistanceService.calculate_distances_with_ids(reference_cell, comparison_cells_with_ids)
    
    unless distances_hash
      Rails.logger.error "Failed to calculate G6 distances for dataset #{target_dataset.id}"
      return
    end

    # Store similarities in database (only for reasonable distances)
    similarities_to_create = []
    distances_hash.each do |other_dataset_id, distance|
      # Skip storing very large distances (> 5000) as they represent very dissimilar cells
      next if distance > 5000.0
      
      # Ensure canonical order (smaller ID first)
      dataset_1_id = [target_dataset.id, other_dataset_id].min
      dataset_2_id = [target_dataset.id, other_dataset_id].max

      similarities_to_create << {
        dataset_1_id: dataset_1_id,
        dataset_2_id: dataset_2_id,
        g6_distance: distance,
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    # Batch insert for efficiency
    if similarities_to_create.any?
      UnitCellSimilarity.insert_all(similarities_to_create)
      Rails.logger.info "Created #{similarities_to_create.count} similarity records for dataset #{target_dataset.id}"
    end

  rescue StandardError => e
    Rails.logger.error "Error computing similarities for dataset #{target_dataset.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  # Class method to trigger computation
  def self.perform_later(target_dataset)
    # Use perform_async if using Sidekiq, or perform_later for ActiveJob
    if defined?(Sidekiq)
      perform_async(target_dataset.id)
    else
      new.perform(target_dataset)
    end
  end

  # Recompute similarities for all existing datasets (useful for initial migration)
  def self.recompute_all_similarities
    Rails.logger.info "Starting recomputation of all unit cell similarities"
    
    # Clear existing similarities
    UnitCellSimilarity.destroy_all
    
    datasets_with_cells = ScxrdDataset.with_primitive_cells.to_a
    total_datasets = datasets_with_cells.count

    Rails.logger.info "Found #{total_datasets} datasets with primitive cells"

    datasets_with_cells.each_with_index do |dataset, index|
      Rails.logger.info "Processing dataset #{index + 1}/#{total_datasets}: #{dataset.id}"
      
      begin
        new.perform(dataset)
      rescue StandardError => e
        Rails.logger.error "Failed to compute similarities for dataset #{dataset.id}: #{e.message}"
      end
    end

    total_similarities = UnitCellSimilarity.count
    Rails.logger.info "Finished recomputing similarities. Total similarity records: #{total_similarities}"
  end
end