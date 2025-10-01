# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"

# Scientific visualization modules (served by Propshaft from app/assets/javascripts/)
pin "scxrd_diffraction_viewer", to: "scxrd_diffraction_viewer.js"
pin "reciprocal_lattice_viewer", to: "reciprocal_lattice_viewer.js"
pin "rod_image_parser", to: "rod_image_parser.js"

# Note: CifVis is loaded via javascript_include_tag as a regular script
