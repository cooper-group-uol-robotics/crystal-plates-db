# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Create units if they don't exist
units_data = [
  # Mass units
  { name: "milligram", symbol: "mg", conversion_to_base: 1.0 },
  { name: "gram", symbol: "g", conversion_to_base: 1000.0 },
  { name: "kilogram", symbol: "kg", conversion_to_base: 1000000.0 },

  # Volume units
  { name: "microliter", symbol: "µl", conversion_to_base: 1.0 },
  { name: "milliliter", symbol: "ml", conversion_to_base: 1000.0 },
  { name: "liter", symbol: "l", conversion_to_base: 1000000.0 },

  # Concentration units
  { name: "molar", symbol: "M", conversion_to_base: 1.0 },
  { name: "millimolar", symbol: "mM", conversion_to_base: 0.001 },
  { name: "micromolar", symbol: "µM", conversion_to_base: 0.000001 },
  { name: "nanomolar", symbol: "nM", conversion_to_base: 0.000000001 },
  { name: "picomolar", symbol: "pM", conversion_to_base: 0.000000000001 },

  # Other units
  { name: "percent", symbol: "%", conversion_to_base: 1.0 },
  { name: "parts per million", symbol: "ppm", conversion_to_base: 1.0 },
  { name: "parts per billion", symbol: "ppb", conversion_to_base: 1.0 }
]

units_data.each do |unit_data|
  Unit.find_or_create_by(symbol: unit_data[:symbol]) do |unit|
    unit.name = unit_data[:name]
    unit.conversion_to_base = unit_data[:conversion_to_base]
  end
end
