class G6DistanceService
  API_ENDPOINT = "/api/v1/g6-distance"

  class << self
    # Calculate G6 distances between unit cells using the API
    # Returns a hash with dataset IDs as keys and distances as values, or nil if API fails
    def calculate_distances_with_ids(reference_cell, comparison_cells_with_ids)
      return nil unless enabled?
      return nil unless valid_unit_cell?(reference_cell)
      return nil if comparison_cells_with_ids.empty?

      # Format request body according to the API specification
      cells = {}
      comparison_cells_with_ids.each do |cell_data|
        dataset_id = cell_data[:dataset_id]
        cell_params = cell_data[:cell_params]
        cells[dataset_id.to_s] = format_cell_for_api(cell_params)
      end

      request_body = {
        reference_cell: format_cell_for_api(reference_cell),
        cells: cells
      }

      Rails.logger.debug "G6 Distance API request: #{request_body.to_json}"

      begin
        connection = Faraday.new(url: base_url) do |faraday|
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = timeout_seconds
        end

        response = connection.post(API_ENDPOINT, request_body)
        Rails.logger.debug "G6 Distance API response: #{response.body.inspect}"

        if response.success? && response.body.is_a?(Array)
          # Parse the response array format: [{"cell_id" => "123", "g6_distance" => 5.0}]
          distances_hash = {}
          response.body.each do |result|
            if result.is_a?(Hash) && result["cell_id"] && result["g6_distance"]
              # The cell_id in response should match the keys we sent in the cells object
              # Try to match it back to our original dataset IDs
              cell_id_str = result["cell_id"].to_s

              # Find the original dataset_id that matches this cell_id
              matching_cell = comparison_cells_with_ids.find { |c| c[:dataset_id].to_s == cell_id_str }
              if matching_cell
                distances_hash[matching_cell[:dataset_id]] = result["g6_distance"].to_f
              else
                # Fallback: try converting to integer
                distances_hash[result["cell_id"].to_i] = result["g6_distance"].to_f
              end
            end
          end
          distances_hash
        else
          Rails.logger.warn "G6 distance API error: #{response.status} - #{response.body}"
          nil
        end
      rescue StandardError => e
        Rails.logger.error "G6 distance API request failed: #{e.message}"
        nil
      end
    end

    # Calculate G6 distances between unit cells using the API (legacy method for backward compatibility)
    # Returns an array of distances or nil if API fails
    def calculate_distances(reference_cell, comparison_cells)
      return nil unless enabled?
      return nil unless valid_unit_cell?(reference_cell)
      return nil if comparison_cells.empty?

      # Convert to the new format with mock IDs
      comparison_cells_with_ids = comparison_cells.each_with_index.map do |cell, index|
        { dataset_id: index + 1, cell_params: cell }
      end

      distances_hash = calculate_distances_with_ids(reference_cell, comparison_cells_with_ids)
      return nil if distances_hash.nil?

      # Convert back to array format in the same order
      comparison_cells.each_with_index.map do |_, index|
        distances_hash[index + 1]
      end
    end

    # Calculate distance between two individual unit cells
    def calculate_distance(cell1, cell2)
      distances = calculate_distances(cell1, [ cell2 ])
      distances&.first
    end

    # Calculate distance between two datasets using their IDs
    def calculate_distance_between_datasets(dataset1, dataset2)
      return nil unless dataset1.has_primitive_cell? && dataset2.has_primitive_cell?

      reference_cell = extract_cell_params(dataset1)
      comparison_cells_with_ids = [ {
        dataset_id: dataset2.id,
        cell_params: extract_cell_params(dataset2)
      } ]

      distances_hash = calculate_distances_with_ids(reference_cell, comparison_cells_with_ids)
      distances_hash&.[](dataset2.id)
    end

    # Find similar datasets using the API
    def find_similar_datasets(reference_dataset, candidates, tolerance: 10.0)
      return [] unless reference_dataset.has_primitive_cell?
      return [] if candidates.empty?

      reference_cell = extract_cell_params(reference_dataset)

      # Format comparison cells with their dataset IDs
      comparison_cells_with_ids = candidates.map do |dataset|
        {
          dataset_id: dataset.id,
          cell_params: extract_cell_params(dataset)
        }
      end

      distances_hash = calculate_distances_with_ids(reference_cell, comparison_cells_with_ids)
      return [] if distances_hash.nil?

      # Filter by tolerance and sort by distance
      similar_datasets = candidates.select do |dataset|
        distance = distances_hash[dataset.id]
        distance && distance <= tolerance
      end.sort_by { |dataset| distances_hash[dataset.id] }

      similar_datasets
    end

    # Calculate similarities for all datasets efficiently
    def calculate_all_similarities(tolerance: 10.0)
      return {} unless enabled?

      # Get all unit cells from the database efficiently
      all_cells = ScxrdDataset.unit_cells_for_api
      return {} if all_cells.empty?

      similarities = {}

      all_cells.each do |reference_data|
        reference_id = reference_data[:dataset_id]
        reference_cell_params = format_cell_array_to_hash(reference_data[:cell_params])

        # Get comparison cells (excluding the reference dataset)
        comparison_cells = all_cells.reject { |c| c[:dataset_id] == reference_id }
        next if comparison_cells.empty?

        # Format comparison cells with their dataset IDs and convert to hash format
        comparison_cells_with_ids = comparison_cells.map do |cell_data|
          {
            dataset_id: cell_data[:dataset_id],
            cell_params: format_cell_array_to_hash(cell_data[:cell_params])
          }
        end

        distances_hash = calculate_distances_with_ids(reference_cell_params, comparison_cells_with_ids)
        next if distances_hash.nil?

        # Filter by tolerance and format for output
        similar_datasets = distances_hash.map do |dataset_id, distance|
          {
            dataset_id: dataset_id,
            distance: distance
          }
        end.select do |data|
          data[:distance] && data[:distance] <= tolerance
        end.sort_by { |data| data[:distance] }

        similarities[reference_id] = similar_datasets if similar_datasets.any?
      end

      similarities
    end

    # Check if API is available
    def api_available?
      return false unless enabled?

      begin
        connection = Faraday.new(url: base_url) do |faraday|
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 5
        end

        response = connection.get("/health")
        response.success?
      rescue StandardError
        false
      end
    end

    # Check if the G6 distance API integration is enabled
    def enabled?
      Setting.conventional_cell_api_endpoint.present?
    end

    private

    def base_url
      Setting.conventional_cell_api_endpoint
    end

    def timeout_seconds
      Setting.conventional_cell_api_timeout
    end

    def format_cell_for_api(cell_params)
      [
        cell_params[:a].to_f,
        cell_params[:b].to_f,
        cell_params[:c].to_f,
        cell_params[:alpha].to_f,
        cell_params[:beta].to_f,
        cell_params[:gamma].to_f
      ]
    end

    def extract_cell_params(dataset)
      # Use primitive cell parameters directly from database
      # The database should already store primitive cells after the optimization
      {
        a: dataset.primitive_a,
        b: dataset.primitive_b,
        c: dataset.primitive_c,
        alpha: dataset.primitive_alpha,
        beta: dataset.primitive_beta,
        gamma: dataset.primitive_gamma
      }
    end

    def valid_unit_cell?(cell_params)
      [ :a, :b, :c, :alpha, :beta, :gamma ].all? do |param|
        cell_params[param].present? && cell_params[param].to_f > 0
      end
    end

    def format_cell_array_to_hash(cell_array)
      {
        a: cell_array[0],
        b: cell_array[1],
        c: cell_array[2],
        alpha: cell_array[3],
        beta: cell_array[4],
        gamma: cell_array[5]
      }
    end
  end
end
