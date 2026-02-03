import { Controller } from "@hotwired/stimulus"
import * as bootstrap from "bootstrap"

// Connects to data-controller="tooltip"
export default class extends Controller {
  connect() {
    // Initialize tooltip for this element
    this.tooltip = new bootstrap.Tooltip(this.element)
  }

  disconnect() {
    // Dispose of tooltip when disconnecting (important for Turbo)
    if (this.tooltip) {
      this.tooltip.dispose()
    }
  }
}
