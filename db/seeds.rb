# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
# Initialize default units
[
  { name: "milligram", symbol: "mg", conversion_to_base: 1.0 },
  { name: "microliter", symbol: "µl", conversion_to_base: 1.0 },
  { name: "milliliter", symbol: "ml", conversion_to_base: 1000.0 },
  { name: "gram", symbol: "g", conversion_to_base: 1000.0 }
].each do |attrs|
  unit = Unit.find_or_create_by!(symbol: attrs[:symbol]) do |u|
    u.name = attrs[:name]
    u.conversion_to_base = attrs[:conversion_to_base]
  end

  # Update existing units if they differ from the expected values
  if unit.name != attrs[:name] || unit.conversion_to_base != attrs[:conversion_to_base]
    unit.update!(name: attrs[:name], conversion_to_base: attrs[:conversion_to_base])
  end
end

# Lattice centrings
seed_file = File.join(Rails.root, 'db', 'seeds', 'lattice_centrings.rb')
load(seed_file) if File.exist?(seed_file)

# Initialize default settings
Setting.initialize_defaults!

# Seed: Generic 96 well Plate Prototype
prototype_name = "Generic 96 well Plate"
unless PlatePrototype.exists?(name: prototype_name)
  prototype = PlatePrototype.create!(name: prototype_name, description: "96 wells, 8 rows x 12 columns, 9mm grid spacing, origin at 0,0, z=0")
  wells = []
  (1..8).each do |row|
    (1..12).each do |col|
      wells << {
        plate_prototype_id: prototype.id,
        well_row: row,
        well_column: col,
        subwell: 1,
        x_mm: (col - 1) * 9.0,
        y_mm: (row - 1) * 9.0,
        z_mm: 0.0,
        created_at: Time.current,
        updated_at: Time.current
      }
    end
  end
  PrototypeWell.insert_all(wells)
  puts "Seeded #{wells.size} wells for prototype '#{prototype_name}'"
end

# Seed: Generic 24 well Plate Prototype
prototype_name = "Generic 24 well Plate"
unless PlatePrototype.exists?(name: prototype_name)
  prototype = PlatePrototype.create!(name: prototype_name, description: "24 wells, 4 rows x 6 columns, 18mm grid spacing, origin at 0,0, z=0")
  wells = []
  (1..4).each do |row|
    (1..6).each do |col|
      wells << PrototypeWell.new(
        plate_prototype: prototype,
        well_row: row,
        well_column: col,
        subwell: 1,
        x_mm: (col - 1) * 18.0,
        y_mm: (row - 1) * 18.0,
        z_mm: 0.0
      )
    end
  end
  PrototypeWell.import wells
  puts "Seeded #{wells.size} wells for prototype '#{prototype_name}'"
end

# Seed: Generic 48 well Plate Prototype
prototype_name = "Generic 48 well Plate"
unless PlatePrototype.exists?(name: prototype_name)
  prototype = PlatePrototype.create!(name: prototype_name, description: "48 wells, 6 rows x 8 columns, 13.5mm grid spacing, origin at 0,0, z=0")
  wells = []
  (1..6).each do |row|
    (1..8).each do |col|
      wells << PrototypeWell.new(
        plate_prototype: prototype,
        well_row: row,
        well_column: col,
        subwell: 1,
        x_mm: (col - 1) * 13.5,
        y_mm: (row - 1) * 13.5,
        z_mm: 0.0
      )
    end
  end
  PrototypeWell.import wells
  puts "Seeded #{wells.size} wells for prototype '#{prototype_name}'"
end

# Seed: Mitegen InSitu-1
prototype_name = "Mitegen InSitu-1"
unless PlatePrototype.exists?(name: prototype_name)
  prototype = PlatePrototype.create!(name: prototype_name, description: "96 wells, 8 rows x 12 columns, 9mm grid spacing")
  wells = []
  (1..8).each do |row|
    (1..12).each do |col|
      wells << PrototypeWell.new(
        plate_prototype: prototype,
        well_row: row,
        well_column: col,
        subwell: 1,
        x_mm: (col - 1) * 9.0 + 2.45,
        y_mm: (row - 1) * 9.0 + 1.38,
        z_mm: -0.2
      )
    end
  end
  (1..8).each do |row|
    (1..12).each do |col|
      wells << PrototypeWell.new(
        plate_prototype: prototype,
        well_row: row,
        well_column: col,
        subwell: 2,
        x_mm: (col - 1) * 9.0 + 2.45,
        y_mm: (row - 1) * 9.0 + 6.49,
        z_mm: -0.2
      )
    end
  end
  PrototypeWell.import wells
  puts "Seeded #{wells.size} wells for prototype '#{prototype_name}'"
end
