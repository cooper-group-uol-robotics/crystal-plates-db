import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bootstrap"
export default class extends Controller {
  connect() {
    // For now, just ensure Bootstrap's data attributes work
    // Most Bootstrap components work automatically with data attributes
    console.debug("Bootstrap controller connected")
  }

  disconnect() {
    // Clean up when the controller disconnects (important for Turbo)
    console.debug("Bootstrap controller disconnected")
  }
}