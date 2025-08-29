class PxrdPattern < ApplicationRecord
  belongs_to :well
  has_one_attached :xrdml_file

  # Parse measured_at timestamp from XRDML file after file is attached
  after_commit :parse_measured_at_from_xrdml, if: :saved_change_to_id?

  # Parse XRDML data for plotting/API access
  def parse_xrdml_data
    return { two_theta: [], intensities: [] } unless xrdml_file.attached?

    begin
      require "nokogiri"
      xrdml_xml = Nokogiri::XML(xrdml_file.download)

      # Extract positions (2θ values)
      positions_element = xrdml_xml.at_xpath("//xmlns:positions[@axis='2Theta']", "xmlns" => "http://www.xrdml.com/XRDMeasurement/1.5")
      positions_text = positions_element&.text&.strip

      # Extract intensities
      intensities_element = xrdml_xml.at_xpath("//xmlns:intensities", "xmlns" => "http://www.xrdml.com/XRDMeasurement/1.5")
      intensities_text = intensities_element&.text&.strip

      if positions_text.present? && intensities_text.present?
        two_theta = positions_text.split.map(&:to_f)
        intensities = intensities_text.split.map(&:to_f)

        { two_theta: two_theta, intensities: intensities }
      else
        { two_theta: [], intensities: [] }
      end
    rescue => e
      Rails.logger.error "Error parsing XRDML data for PxrdPattern #{id}: #{e.message}"
      { two_theta: [], intensities: [] }
    end
  end

  private

  def parse_measured_at_from_xrdml
    return unless xrdml_file.attached?

    begin
      require "nokogiri"
      xrdml_xml = Nokogiri::XML(xrdml_file.download)
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
