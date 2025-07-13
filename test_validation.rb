#!/usr/bin/env ruby

# Test the location validation logic
puts "=== Testing Location Validation ==="

# Load Rails environment
require_relative 'config/environment'

location = Location.find(1)
puts "Testing location: #{location.display_name}"

# Test the exact query from validate_location_availability
latest_locations_subquery = PlateLocation
  .select("plate_id, MAX(id) as latest_id")
  .group(:plate_id)

puts "Subquery SQL: #{latest_locations_subquery.to_sql}"

occupied_by = PlateLocation.joins(:plate)
                          .joins("INNER JOIN (#{latest_locations_subquery.to_sql}) latest ON plate_locations.plate_id = latest.plate_id AND plate_locations.id = latest.latest_id")
                          .where(location: location)
                          .includes(:plate)
                          .first

puts "Query result: #{occupied_by.inspect}"

if occupied_by
  puts "Location IS occupied by plate: #{occupied_by.plate.barcode}"
  puts "This should cause validation to FAIL"
else
  puts "Location appears to be available"
  puts "This would allow the validation to PASS"
end

# Let's also check what plates are at this location using the model method
puts "\n=== Using model method ==="
plates_at_location = Plate.currently_at_location(location)
puts "Plates currently at location: #{plates_at_location.map(&:barcode)}"

# Check the current location of all plates
puts "\n=== All plates and their current locations ==="
Plate.all.each do |plate|
  current_loc = plate.current_location
  puts "Plate #{plate.barcode}: #{current_loc ? current_loc.display_name : 'No location'}"
end
