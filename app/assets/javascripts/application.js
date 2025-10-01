// Simple application JavaScript - no frameworks needed
console.log("Application.js loaded");

// Import Turbo for handling data-method attributes (DELETE, etc.)
import "@hotwired/turbo-rails"

// Import SCXRD Diffraction Viewer
import "./scxrd_diffraction_viewer"

// Import Reciprocal Lattice Viewer
import "./reciprocal_lattice_viewer"

// Note: CifVis is loaded via script tag to avoid module format conflicts
// Note: ROD Image Parser loaded via importmap pin