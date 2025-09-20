class PxrdPattern < ApplicationRecord
  belongs_to :well, optional: true
  has_one_attached :pxrd_data_file

  # Parse measured_at timestamp from XRDML file after file is attached
  after_commit :parse_measured_at_from_xrdml, if: :saved_change_to_id?

  # Parse diffraction data for plotting/API access (supports .xrdml and .xye formats)
  def parse_diffraction_data
    return { two_theta: [], intensities: [], format: nil, wavelength: nil } unless pxrd_data_file.attached?

    begin
      filename = pxrd_data_file.filename.to_s.downcase
      file_extension = File.extname(filename)
      raw_content = pxrd_data_file.download

      case file_extension
      when ".xye"
        parse_xye_data(raw_content)
      when ".xrdml"
        parse_xrdml_file_data(raw_content)
      else
        Rails.logger.error "Unsupported file format for PxrdPattern #{id}: #{file_extension}"
        { two_theta: [], intensities: [], format: file_extension, wavelength: nil }
      end
    rescue => e
      Rails.logger.error "Error parsing diffraction data for PxrdPattern #{id}: #{e.message}"
      { two_theta: [], intensities: [], format: nil, wavelength: nil }
    end
  end

  def file_format
    return nil unless pxrd_data_file.attached?
    File.extname(pxrd_data_file.filename.to_s.downcase)
  end

  private

  def parse_xye_data(raw_content)
    lines = raw_content.split("\n")
    data_lines = lines.reject { |line| line.strip.empty? || line.strip.start_with?("/*", "#") }

    two_theta = []
    intensities = []

    data_lines.each do |line|
      columns = line.strip.split
      next if columns.size < 2

      # First column is 2theta, second is intensity
      two_theta << columns[0].to_f
      intensities << columns[1].to_f
    end

    { two_theta: two_theta, intensities: intensities, format: ".xye", wavelength: nil }
  end

  def parse_xrdml_file_data(raw_content)
    require "nokogiri"
    xrdml_xml = Nokogiri::XML(raw_content)

    # Try different namespace versions
    namespaces = [
      "http://www.xrdml.com/XRDMeasurement/1.5",
      "http://www.xrdml.com/XRDMeasurement/1.7",
      "http://www.xrdml.com/XRDMeasurement/2.0"
    ]

    two_theta = []
    intensities = []

    Rails.logger.debug "XRDML Parsing - Root element: #{xrdml_xml.root&.name}"
    Rails.logger.debug "XRDML Parsing - Available namespaces: #{xrdml_xml.namespaces}"

    # First try direct position/intensity extraction
    namespaces.each do |ns|
      positions_element = xrdml_xml.at_xpath("//xmlns:positions[@axis='2Theta']", "xmlns" => ns)
      intensities_element = xrdml_xml.at_xpath("//xmlns:intensities", "xmlns" => ns)

      Rails.logger.debug "XRDML Parsing - Namespace #{ns}: positions found: #{!positions_element.nil?}, intensities found: #{!intensities_element.nil?}"

      if positions_element&.text&.present? && intensities_element&.text&.present?
        positions_text = positions_element.text.strip
        intensities_text = intensities_element.text.strip

        Rails.logger.debug "XRDML Parsing - Positions text length: #{positions_text.length}, preview: #{positions_text[0, 100]}"
        Rails.logger.debug "XRDML Parsing - Intensities text length: #{intensities_text.length}, preview: #{intensities_text[0, 100]}"

        two_theta_positions = positions_text.split.map(&:to_f)
        intensities = intensities_text.split.map(&:to_f)

        Rails.logger.debug "XRDML Parsing - Found #{two_theta_positions.size} 2theta positions, #{intensities.size} intensities"

        # If we have only 2 positions (start and end) but many intensities, interpolate
        if two_theta_positions.size == 2 && intensities.size > 2
          start_2theta = two_theta_positions.first
          end_2theta = two_theta_positions.last
          n_points = intensities.size
          step = (end_2theta - start_2theta) / (n_points - 1)

          Rails.logger.debug "XRDML Parsing - Interpolating between #{start_2theta} and #{end_2theta} for #{n_points} points"
          two_theta = Array.new(n_points) { |i| (start_2theta + i * step) }
        elsif two_theta_positions.size == intensities.size
          # Direct mapping if sizes match
          two_theta = two_theta_positions
        else
          Rails.logger.debug "XRDML Parsing - Size mismatch: #{two_theta_positions.size} positions vs #{intensities.size} intensities"
          next # Try next namespace or method
        end

        break if two_theta.any? && intensities.any?
      end
    end

    # If direct extraction failed, try start/end position method
    if two_theta.empty? || intensities.empty?
      Rails.logger.debug "XRDML Parsing - Direct extraction failed, trying start/end method"

      namespaces.each do |ns|
        start_2theta = xrdml_xml.at_xpath('//xmlns:dataPoints/xmlns:positions[@axis="2Theta"]//xmlns:startPosition', "xmlns" => ns)&.text&.to_f
        end_2theta = xrdml_xml.at_xpath('//xmlns:dataPoints/xmlns:positions[@axis="2Theta"]//xmlns:endPosition', "xmlns" => ns)&.text&.to_f
        intensities_str = xrdml_xml.at_xpath("//xmlns:dataPoints/xmlns:intensities", "xmlns" => ns)&.text

        Rails.logger.debug "XRDML Parsing - Start/End method - Namespace #{ns}: start=#{start_2theta}, end=#{end_2theta}, intensities_present=#{intensities_str.present?}"

        if start_2theta && end_2theta && intensities_str.present?
          intensities_array = intensities_str.split.map(&:to_f)
          n_points = intensities_array.size
          step = (end_2theta - start_2theta) / (n_points - 1)

          Rails.logger.debug "XRDML Parsing - Generating #{n_points} 2theta points from #{start_2theta} to #{end_2theta}"

          two_theta = Array.new(n_points) { |i| (start_2theta + i * step) }
          intensities = intensities_array
          break
        end
      end
    end

    # Try without namespace if still no success
    if two_theta.empty? || intensities.empty?
      Rails.logger.debug "XRDML Parsing - Trying without namespace"

      positions_element = xrdml_xml.at_xpath("//positions[@axis='2Theta']")
      intensities_element = xrdml_xml.at_xpath("//intensities")

      Rails.logger.debug "XRDML Parsing - No namespace: positions found: #{!positions_element.nil?}, intensities found: #{!intensities_element.nil?}"

      if positions_element&.text&.present? && intensities_element&.text&.present?
        two_theta = positions_element.text.strip.split.map(&:to_f)
        intensities = intensities_element.text.strip.split.map(&:to_f)
        Rails.logger.debug "XRDML Parsing - No namespace extracted #{two_theta.size} points"
      end
    end

    Rails.logger.debug "XRDML Parsing - Final result: #{two_theta.size} data points"

    # Extract wavelength information
    wavelength = nil
    namespaces.each do |ns|
      wavelength_element = xrdml_xml.at_xpath("//xmlns:usedWavelength/xmlns:kAlpha1", "xmlns" => ns) ||
                          xrdml_xml.at_xpath("//xmlns:wavelength", "xmlns" => ns) ||
                          xrdml_xml.at_xpath("//xmlns:kAlpha1", "xmlns" => ns)
      if wavelength_element&.text&.present?
        wavelength = wavelength_element.text.to_f
        Rails.logger.debug "XRDML Parsing - Found wavelength: #{wavelength} Å"
        break
      end
    end

    # Try without namespace for wavelength
    if wavelength.nil?
      wavelength_element = xrdml_xml.at_xpath("//usedWavelength/kAlpha1") ||
                          xrdml_xml.at_xpath("//wavelength") ||
                          xrdml_xml.at_xpath("//kAlpha1")
      if wavelength_element&.text&.present?
        wavelength = wavelength_element.text.to_f
        Rails.logger.debug "XRDML Parsing - Found wavelength (no namespace): #{wavelength} Å"
      end
    end

    { two_theta: two_theta, intensities: intensities, format: ".xrdml", wavelength: wavelength }
  end

  def parse_measured_at_from_xrdml
    return unless pxrd_data_file.attached?

    begin
      require "nokogiri"
      xrdml_xml = Nokogiri::XML(pxrd_data_file.download)
      start_timestamp_str = xrdml_xml.at_xpath("//xmlns:startTimeStamp", "xmlns" => "http://www.xrdml.com/XRDMeasurement/1.5")&.text

      if start_timestamp_str.present?
        parsed_time = Time.parse(start_timestamp_str)
        update_column(:measured_at, parsed_time)
      end
    rescue => e
      Rails.logger.warn "Could not parse measured_at from XRDML file for PxrdPattern #{id}: #{e.message}"
    end
  end
end
