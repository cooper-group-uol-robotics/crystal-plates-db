# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
Unit.create!([
  { name: "milligram", symbol: "mg", conversion_to_base: 1.0 },
  { name: "microliter", symbol: "µl", conversion_to_base: 1.0 },
  { name: "milliliter", symbol: "ml", conversion_to_base: 1000.0 },
  { name: "gram", symbol: "g", conversion_to_base: 1000.0 }
])

# Create locations for carousel positions 1-10 with hotel positions 1-20
puts "Creating carousel and hotel positions..."
(1..10).each do |carousel_pos|
  (1..20).each do |hotel_pos|
    Location.find_or_create_by!(
      carousel_position: carousel_pos,
      hotel_position: hotel_pos
    )
  end
end

# Create special locations
puts "Creating special locations..."
Location.find_or_create_by!(name: "imager")

puts "Created #{Location.count} locations"
