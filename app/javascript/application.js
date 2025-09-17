// Simple application JavaScript - no frameworks needed
console.log("Application.js loaded");

// Import Turbo for handling data-method attributes (DELETE, etc.)
import "@hotwired/turbo-rails"

// ActionCable integration commented out to avoid asset compilation issues
// Will use polling for auto-segmentation status instead

// Import SCXRD Diffraction Viewer
import "./scxrd_diffraction_viewer"

// Import Reciprocal Lattice Viewer
import "./reciprocal_lattice_viewer"
