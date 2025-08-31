namespace :pxrd_patterns do
  desc "Parse measured_at timestamps from existing XRDML files"
  task parse_timestamps: :environment do
    require "nokogiri"

    count = 0
    errors = 0

    PxrdPattern.where(measured_at: nil).includes(pxrd_data_file_attachment: :blob).find_each do |pattern|
      next unless pattern.pxrd_data_file.attached?

      begin
        xrdml_xml = Nokogiri::XML(pattern.pxrd_data_file.download)
        start_timestamp_str = xrdml_xml.at_xpath("//xmlns:startTimeStamp", "xmlns" => "http://www.xrdml.com/XRDMeasurement/1.5")&.text

        if start_timestamp_str.present?
          parsed_time = Time.parse(start_timestamp_str)
          pattern.update_column(:measured_at, parsed_time)
          puts "Updated PxrdPattern ##{pattern.id}: #{parsed_time}"
          count += 1
        else
          puts "No startTimeStamp found in PxrdPattern ##{pattern.id}"
        end
      rescue => e
        puts "Error parsing PxrdPattern ##{pattern.id}: #{e.message}"
        errors += 1
      end
    end

    puts "Finished: Updated #{count} patterns, #{errors} errors"
  end
end
