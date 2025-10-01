# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"

# Custom JavaScript modules
pin "plates_show"
pin "cifvis.alldeps"
pin "pxrd_chart"
pin_all_from "app/javascript/scxrd", under: "scxrd"

# Bootstrap and Popper.js
pin "@popperjs/core", to: "https://cdn.jsdelivr.net/npm/@popperjs/core@2.11.8/dist/esm/index.js"
pin "bootstrap", to: "https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.esm.min.js"

# Chart.js and plugins (ESM versions from esm.sh)
pin "chart.js", to: "https://esm.sh/chart.js@4.4.0"
pin "chartjs-plugin-zoom", to: "https://esm.sh/chartjs-plugin-zoom@2.0.1"
