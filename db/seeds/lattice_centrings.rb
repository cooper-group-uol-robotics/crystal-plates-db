# Seed lattice centring types
LatticeCentring.find_or_create_by!(symbol: 'P', description: 'Primitive')
LatticeCentring.find_or_create_by!(symbol: 'C', description: 'Base-centered')
LatticeCentring.find_or_create_by!(symbol: 'I', description: 'Body-centered')
LatticeCentring.find_or_create_by!(symbol: 'F', description: 'Face-centered')
