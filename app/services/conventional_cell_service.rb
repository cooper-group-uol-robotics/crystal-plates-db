class ConventionalCellService
  # API configuration from Rails config
  API_ENDPOINT = "/api/v1/lepage"

  class << self
    # Convert primitive cell to conventional cells using unit cell conversion API
    # Returns an array of conventional cell options, or nil if API fails
    def convert_to_conventional(primitive_a, primitive_b, primitive_c, primitive_alpha, primitive_beta, primitive_gamma, max_delta: nil)
      return nil unless enabled?
      return nil unless valid_primitive_cell?(primitive_a, primitive_b, primitive_c, primitive_alpha, primitive_beta, primitive_gamma)

      max_delta ||= Setting.conventional_cell_max_delta

      request_body = {
        cell: [
          primitive_a.to_f,
          primitive_b.to_f,
          primitive_c.to_f,
          primitive_alpha.to_f,
          primitive_beta.to_f,
          primitive_gamma.to_f
        ],
        lepage_max_delta: max_delta.to_f
      }

      begin
        connection = Faraday.new(url: base_url) do |faraday|
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = timeout_seconds
        end

        response = connection.post(API_ENDPOINT, request_body)

        if response.success? && response.body.is_a?(Array)
          response.body.map { |cell_data| parse_conventional_cell(cell_data) }.compact
        else
          Rails.logger.warn "Unit cell conversion API error: #{response.status} - #{response.body}"
          nil
        end
      rescue StandardError => e
        Rails.logger.error "Unit cell conversion API request failed: #{e.message}"
        nil
      end
    end

    # Get the best conventional cell (lowest distance/highest symmetry)
    def best_conventional_cell(primitive_a, primitive_b, primitive_c, primitive_alpha, primitive_beta, primitive_gamma, max_delta: nil)
      return nil unless enabled?

      conventional_cells = convert_to_conventional(primitive_a, primitive_b, primitive_c, primitive_alpha, primitive_beta, primitive_gamma, max_delta: max_delta)
      return nil unless conventional_cells&.any?

      # Sort by distance (lower is better) then by bravais lattice preference
      # Prefer higher symmetry lattices (non-triclinic over triclinic)
      conventional_cells.first
    end

    def conventional_cell_as_input(primitive_a, primitive_b, primitive_c, primitive_alpha, primitive_beta, primitive_gamma, max_delta: nil)
      return nil unless enabled?

      conventional_cells = convert_to_conventional(primitive_a, primitive_b, primitive_c, primitive_alpha, primitive_beta, primitive_gamma, max_delta: max_delta)
      return nil unless conventional_cells&.any?

      conventional_cells.last
    end

    # Check if API is available
    def api_available?
      return false unless enabled?

      begin
        connection = Faraday.new(url: base_url) do |faraday|
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = 2
        end

        response = connection.get("/health")
        response.success?
      rescue StandardError
        false
      end
    end

    # Check if the unit cell conversion API integration is enabled
    def enabled?
      true  # Always enabled
    end

    private

    def base_url
      Setting.conventional_cell_api_endpoint
    end

    def timeout_seconds
      Setting.conventional_cell_api_timeout
    end

    def valid_primitive_cell?(a, b, c, alpha, beta, gamma)
      [ a, b, c, alpha, beta, gamma ].all? { |param| param.present? && param.to_f > 0 }
    end

    def parse_conventional_cell(cell_data)
      return nil unless cell_data.is_a?(Hash) && cell_data["conventional_cell"].is_a?(Array)

      conventional = cell_data["conventional_cell"]
      {
        bravais: cell_data["bravais"],
        cb_op: cell_data["cb_op"],
        a: conventional[0],
        b: conventional[1],
        c: conventional[2],
        alpha: conventional[3],
        beta: conventional[4],
        gamma: conventional[5],
        volume: cell_data["volume"],
        distance: cell_data["distance"] || 0
      }
    end
  end
end
