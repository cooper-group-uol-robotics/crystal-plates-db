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

# Create some example chemicals if they don't exist
chemicals = [
  { name: "Sodium Chloride", cas: "7647-14-5", sciformation_id: 1 },
  { name: "Potassium Chloride", cas: "7447-40-7", sciformation_id: 2 },
  { name: "Calcium Chloride", cas: "10043-52-4", sciformation_id: 3 },
  { name: "Magnesium Sulfate", cas: "7487-88-9", sciformation_id: 4 },
  { name: "Tris Base", cas: "77-86-1", sciformation_id: 5 }
]

chemicals.each do |chem_data|
  Chemical.find_or_create_by(name: chem_data[:name]) do |chemical|
    chemical.cas = chem_data[:cas]
    chemical.sciformation_id = chem_data[:sciformation_id]
    chemical.smiles = "C" # Placeholder SMILES
  end
end

# Create some example stock solutions
if StockSolution.count == 0
  # PBS Buffer Stock Solution
  pbs = StockSolution.create!(name: "PBS Buffer 10x")

  # Find units
  mg_unit = Unit.find_by(symbol: "mg")

  # Add components to PBS
  pbs.stock_solution_components.create!([
    { chemical: Chemical.find_by(name: "Sodium Chloride"), amount: 80.0, unit: mg_unit },
    { chemical: Chemical.find_by(name: "Potassium Chloride"), amount: 2.0, unit: mg_unit },
    { chemical: Chemical.find_by(name: "Calcium Chloride"), amount: 1.0, unit: mg_unit }
  ])

  # Tris Buffer Stock Solution
  tris = StockSolution.create!(name: "Tris Buffer 1M")
  tris.stock_solution_components.create!([
    { chemical: Chemical.find_by(name: "Tris Base"), amount: 121.1, unit: mg_unit }
  ])

  puts "Created #{StockSolution.count} stock solutions with components"
end
