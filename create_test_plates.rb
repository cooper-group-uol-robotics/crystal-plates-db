#!/usr/bin/env ruby
# Create test plates for pagination demo

require_relative 'config/environment'

puts "Creating test plates..."

(1..30).each do |i|
  begin
    plate = Plate.create!(
      plate_rows: 8,
      plate_columns: 12,
      plate_subwells_per_well: 1
    )
    puts "Created plate: #{plate.barcode}"
  rescue => e
    puts "Error creating plate #{i}: #{e.message}"
  end
end

puts "Total plates: #{Plate.count}"
