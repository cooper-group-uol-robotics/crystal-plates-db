# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "three", to: "https://cdn.jsdelivr.net/npm/three@0.172.0/build/three.module.js"
pin "three/addons/controls/OrbitControls.js", to: "https://cdn.jsdelivr.net/npm/three@0.172.0/examples/jsm/controls/OrbitControls.js"

# Stimulus controllers - these are served directly from app/javascript/controllers
pin_all_from "app/javascript/controllers", under: "controllers"

# Main application modules - these are served directly from app/javascript
pin "rod_image_parser"
pin "plates_show"

# SCXRD related modules - these are served directly from app/javascript/scxrd
pin "scxrd/diffraction_viewer"
pin "scxrd/card_toggler"
pin "scxrd/reciprocal_lattice_viewer"
pin "scxrd/gallery"

# WASM modules - these are served directly from public/wasm
pin "wasm/rod_decoder", to: "/wasm/rod_decoder.js"

# CifVis library for 3D crystal structure visualization - served locally (includes Three.js)
pin "cifvis", to: "cifvis.alldeps.js"
