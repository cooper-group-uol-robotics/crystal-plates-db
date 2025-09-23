# Pin npm packages by running ./bin/importmap

pin "application", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js"
# ActionCable and channels removed - using polling instead
# pin "@rails/actioncable", to: "actioncable.esm.js"
# pin_all_from "app/javascript/channels", under: "channels"

# SCXRD Diffraction Viewer using Visual Heatmap
pin "scxrd_diffraction_viewer", to: "scxrd_diffraction_viewer.js"

# ROD Image Parser for client-side decompression
pin "rod_image_parser", to: "rod_image_parser.js"

# SCXRD Reciprocal Lattice Viewer using Three.js
pin "reciprocal_lattice_viewer", to: "reciprocal_lattice_viewer.js"

# Note: CifVis is loaded via javascript_include_tag as a regular script
