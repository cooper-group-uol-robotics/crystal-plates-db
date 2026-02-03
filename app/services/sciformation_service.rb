class SciformationService
  require "net/http"
  require "uri"
  require "json"

  BASE_URL = "https://sciformation.liverpool.ac.uk"
  LOGIN_URL = "#{BASE_URL}/login"
  SEARCH_URL = "#{BASE_URL}/performSearch"

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

  # Authenticate and establish a session with Sciformation
  def authenticate!
    uri = URI(LOGIN_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    http.open_timeout = 15

    request = Net::HTTP::Post.new(uri)
    request.set_form_data({
      "user" => @username,
      "password" => @password,
      "preventSaml2" => "true"
    })

    Rails.logger.info "Authenticating with Sciformation as user: #{@username}"

    begin
      response = http.request(request)

      if response.code.to_i == 302 || response.code.to_i == 200
        # Extract cookies from response
        @cookies = response.get_fields("set-cookie")&.map { |c| c.split(";").first }&.join("; ")

        if @cookies.present?
          Rails.logger.info "Successfully authenticated with Sciformation"
          true
        else
          raise AuthenticationError, "No session cookies returned from Sciformation"
        end
      else
        raise AuthenticationError, "Authentication failed - HTTP #{response.code}"
      end

    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise AuthenticationError, "Timeout connecting to Sciformation: #{e.message}"
    rescue => e
      raise AuthenticationError, "Authentication error: #{e.message}"
    end
  end

  # Fetch chemicals from a COSHH form code (e.g., "TFE-045")
  def fetch_coshh_chemicals(coshh_code)
    authenticate! unless @cookies.present?

    # Parse COSHH code (e.g., "TFE-045" -> prefix: "TFE", number: 45)
    coshh_prefix, coshh_number = parse_coshh_code(coshh_code)

    unless coshh_prefix && coshh_number
      raise QueryError, "Invalid COSHH code format: #{coshh_code}"
    end

    # Build query for Sciformation
    criteria = {
      "elnReactionComponentCollection.elnReaction.elnLabNotebook.code" => coshh_prefix,
      "elnReactionComponentCollection.elnReaction.nrInLabJournal" => coshh_number
    }

    results = perform_search("CdbContainer", criteria)

    # Extract only the Sciformation IDs (pk) from containers
    sciformation_ids = results.map { |item| item["pk"] }.compact

    Rails.logger.info "Found #{sciformation_ids.size} chemical IDs for COSHH form #{coshh_code}"
    sciformation_ids
  end

  # Fetch inventory containers (existing functionality)
  def fetch_inventory(department_id: "124", barcode: nil)
    authenticate! unless @cookies.present?

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
    request["Cookie"] = @cookies

    # Build query string
    query_parts = criteria.keys.each_with_index.map { |_, i| "[#{i}]" }
    query = query_parts.join("+AND+")

    # Build form data
    form_data = {
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
