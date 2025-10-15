class PrimitiveCellService
  API_ENDPOINT = "/api/v1/lepage"

  class << self
    # Convert a cell to its primitive form using the lepage API
    # Returns the primitive cell parameters as a hash, or nil if API fails
    def convert_to_primitive(a, b, c, alpha, beta, gamma)
      return nil unless enabled?
      return nil unless valid_unit_cell?(a, b, c, alpha, beta, gamma)

      request_body = {
        cell: [
          a.to_f,
          b.to_f,
          c.to_f,
          alpha.to_f,
          beta.to_f,
          gamma.to_f
        ],
        lepage_max_delta: Setting.conventional_cell_max_delta
      }

      Rails.logger.debug "PrimitiveCellService: Converting cell to primitive: #{request_body[:cell]}"

      begin
        connection = Faraday.new(url: base_url) do |faraday|
          faraday.request :json
          faraday.response :json
          faraday.adapter Faraday.default_adapter
          faraday.options.timeout = timeout_seconds
        end

        response = connection.post(API_ENDPOINT, request_body)

        if response.success? && response.body.is_a?(Array)
          # The lepage API returns conventional cells, but we want the primitive one
          # The primitive cell is typically the first entry or the one with bravais "aP"
          primitive_cell = find_primitive_cell(response.body)
          
          if primitive_cell
            Rails.logger.debug "PrimitiveCellService: Found primitive cell: #{primitive_cell}"
            primitive_cell
          else
            Rails.logger.warn "PrimitiveCellService: No primitive cell found in response"
            nil
          end
        else
          Rails.logger.warn "PrimitiveCellService API error: #{response.status} - #{response.body}"
          nil
        end
      rescue StandardError => e
        Rails.logger.error "PrimitiveCellService API request failed: #{e.message}"
        nil
      end
    end

    # Check if a cell is already primitive by comparing it with the converted result
    # Returns true if the cell is already primitive (within tolerance)
    def is_primitive?(a, b, c, alpha, beta, gamma, tolerance: 1e-6)
      return false unless enabled?
      
      primitive_cell = convert_to_primitive(a, b, c, alpha, beta, gamma)
      return false unless primitive_cell

      # Compare the original cell with the primitive result
      original_params = [a.to_f, b.to_f, c.to_f, alpha.to_f, beta.to_f, gamma.to_f]
      primitive_params = [
        primitive_cell[:a], primitive_cell[:b], primitive_cell[:c],
        primitive_cell[:alpha], primitive_cell[:beta], primitive_cell[:gamma]
      ]

      # Check if they're equal within tolerance
      original_params.zip(primitive_params).all? do |orig, prim|
        (orig - prim).abs < tolerance
      end
    end

    # Ensure a cell is in primitive form, converting if necessary
    # Returns primitive cell parameters, or the original if already primitive
    def ensure_primitive(a, b, c, alpha, beta, gamma)
      return nil unless enabled?
      return nil unless valid_unit_cell?(a, b, c, alpha, beta, gamma)

      # First try to convert to primitive
      primitive_cell = convert_to_primitive(a, b, c, alpha, beta, gamma)
      
      if primitive_cell
        primitive_cell
      else
        # If conversion fails, return the original cell as a fallback
        Rails.logger.warn "PrimitiveCellService: Conversion failed, using original cell as fallback"
        {
          a: a.to_f,
          b: b.to_f,
          c: c.to_f,
          alpha: alpha.to_f,
          beta: beta.to_f,
          gamma: gamma.to_f
        }
      end
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

    # Check if the primitive cell API integration is enabled
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

    def valid_unit_cell?(a, b, c, alpha, beta, gamma)
      [a, b, c, alpha, beta, gamma].all? { |param| param.present? && param.to_f > 0 }
    end

    def find_primitive_cell(lepage_response)
      return nil unless lepage_response.is_a?(Array) && lepage_response.any?

      # Look for the primitive cell (bravais "aP") or use the first entry as fallback
      primitive_entry = lepage_response.find { |entry| entry["bravais"] == "aP" }
      primitive_entry ||= lepage_response.first

      return nil unless primitive_entry && primitive_entry["conventional_cell"].is_a?(Array)

      conventional = primitive_entry["conventional_cell"]
      {
        a: conventional[0],
        b: conventional[1],
        c: conventional[2],
        alpha: conventional[3],
        beta: conventional[4],
        gamma: conventional[5],
        bravais: primitive_entry["bravais"],
        distance: primitive_entry["distance"] || 0
      }
    end
  end
end