class PxrdPattern < ApplicationRecord
  belongs_to :well
  has_one_attached :xrdml_file

  # Parse measured_at timestamp from XRDML file after file is attached
  after_commit :parse_measured_at_from_xrdml, if: :saved_change_to_id?

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
