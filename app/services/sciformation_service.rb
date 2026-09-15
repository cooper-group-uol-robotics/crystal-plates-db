class SciformationService
  require "digest"
  require "net/http"
  require "uri"
  require "json"

  BASE_URL = "https://sciformation.liverpool.ac.uk"
  LOGIN_URL = "#{BASE_URL}/login"
  SEARCH_URL = "#{BASE_URL}/login?useCase=performSearch"
  COSHH_CACHE_TTL = 12.hours

  class AuthenticationError < StandardError; end
  class QueryError < StandardError; end

  def initialize(username: nil, password: nil)
    @username = username || Setting.sciformation_username
    @password = password || Setting.sciformation_password

    if @username.blank? || @password.blank?
      raise AuthenticationError, "Sciformation credentials not configured"
    end

    @cookies = nil
  end


  # Fetch chemicals from a COSHH form code (e.g., "TFE-045")
  def fetch_coshh_chemicals(coshh_code)
    # Parse COSHH code (e.g., "TFE-045" -> prefix: "TFE", number: 45)
    coshh_prefix, coshh_number = parse_coshh_code(coshh_code)

    unless coshh_prefix && coshh_number
      raise QueryError, "Invalid COSHH code format: #{coshh_code}"
    end

    cache_key = "sciformation:coshh-chemicals:#{Digest::SHA256.hexdigest([ @username, coshh_prefix, coshh_number ].join(":"))}"

    cache_hit = true
    sciformation_ids = Rails.cache.fetch(cache_key, expires_in: COSHH_CACHE_TTL) do
      cache_hit = false

      criteria = {
        "elnReactionComponentCollection.elnReaction.elnLabNotebook.code" => coshh_prefix,
        "elnReactionComponentCollection.elnReaction.nrInLabJournal" => coshh_number
      }

      results = perform_search("CdbContainer", criteria)
      results.map { |item| item["pk"] }.compact
    end

    Rails.logger.info "[Sciformation] Using cached COSHH chemicals for #{coshh_code}" if cache_hit

    Rails.logger.info "Found #{sciformation_ids.size} chemical IDs for COSHH form #{coshh_code}"
    sciformation_ids
  end

  # Fetch inventory containers (existing functionality)
  def fetch_inventory(department_id: "124", barcode: nil)
    if barcode.present?
      criteria = { "barcode" => barcode }
    else
      criteria = { "department" => department_id }
    end

    perform_search("CdbContainer", criteria)
  end

  private

  # Parse COSHH code like "TFE-045" into prefix and number (trimming leading zeros)
  def parse_coshh_code(code)
    return nil unless code.present?

    # Match pattern: letters/numbers, hyphen, number
    match = code.match(/\A([A-Za-z0-9\_]+)-(\d+)\z/)
    return nil unless match

    prefix = match[1]
    number = match[2].to_i  # This automatically trims leading zeros

    [ prefix, number ]
  end

  # Perform a search query on Sciformation
  def perform_search(table, criteria)
    uri = URI(SEARCH_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60
    http.open_timeout = 30

    request = Net::HTTP::Post.new(uri)
    # Build query string
    query_parts = criteria.keys.each_with_index.map { |_, i| "[#{i}]" }
    query = query_parts.join("+AND+")

    # Build form data
    form_data = {
      "user" => @username,
      "password" => @password,
      "preventSaml2" => "true",
      "table" => table,
      "format" => "json",
      "query" => query
    }

    criteria.each_with_index do |(key, value), i|
      form_data["crit#{i}"] = key
      form_data["val#{i}"] = value.to_s
    end

    Rails.logger.debug "Sciformation search: table=#{table}, criteria=#{criteria.inspect}"
    request.set_form_data(form_data)

    begin
      response = http.request(request)

      if response.code.to_i == 200
        data = JSON.parse(response.body)

        unless data.is_a?(Array)
          raise QueryError, "Unexpected response format from Sciformation"
        end

        Rails.logger.debug "Sciformation returned #{data.size} results"
        data
      else
        raise QueryError, "Search failed - HTTP #{response.code}"
      end

    rescue JSON::ParserError => e
      raise QueryError, "Invalid JSON response: #{e.message}"
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise QueryError, "Timeout during search: #{e.message}"
    rescue => e
      raise QueryError, "Search error: #{e.message}"
    end
  end
end
