import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="interactive-image"
export default class extends Controller {
  static targets = [
    "image",
    "overlay", 
    "pointsList",
    "pointsCount",
    "pointsTableContainer",
    "clearPointsBtn",
    "togglePointsBtn",
    "autoSegmentBtn"
  ]

  static values = {
    imageId: Number,
    wellId: Number,
    originalWidth: Number,
    originalHeight: Number,
    prevWellUrl: String,
    nextWellUrl: String,
    prevImageUrl: String,
    nextImageUrl: String
  }

  connect() {
    console.log("Interactive image controller connected - ID:", Math.random().toString(36).substr(2, 9))
    console.log("Image target:", this.imageTarget)
    console.log("Image ID:", this.imageIdValue, "Well ID:", this.wellIdValue)
    console.log("Original dimensions:", this.originalWidthValue, "x", this.originalHeightValue)
    
    this.points = []
    this.pointsVisible = true
    this.segmentationSubscription = null
    
    this.setupEventListeners()
    this.loadExistingPoints()
    this.setupKeyboardNavigation()
  }

  disconnect() {
    console.log("Interactive image controller disconnected")
    if (this.segmentationSubscription) {
      this.segmentationSubscription.disconnect()
    }
    // Clean up keyboard event listener
    if (this.keyboardHandler) {
      document.removeEventListener("keydown", this.keyboardHandler)
    }
  }

  setupEventListeners() {
    console.log("Setting up event listeners for image target:", this.imageTarget)
    
    // Image load handler to ensure we have correct dimensions  
    this.imageTarget.addEventListener("load", () => this.refreshPointPositions())
  }

  setupKeyboardNavigation() {
    // Remove any existing keyboard listener to prevent duplicates
    if (this.keyboardHandler) {
      document.removeEventListener("keydown", this.keyboardHandler)
    }

    this.keyboardHandler = (e) => {
      if (["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(e.key)) {
        e.preventDefault()
        this.handleKeyboardNavigation(e.key)
      }
    }

    document.addEventListener("keydown", this.keyboardHandler)
  }

  handleKeyboardNavigation(key) {
    console.log("Arrow key pressed:", key)
    
    switch(key) {
      case "ArrowLeft":
        if (this.prevWellUrlValue) {
          console.log("Navigating to prevWellUrl:", this.prevWellUrlValue)
          window.location.href = this.prevWellUrlValue
        }
        break
      case "ArrowRight":
        if (this.nextWellUrlValue) {
          console.log("Navigating to nextWellUrl:", this.nextWellUrlValue)
          window.location.href = this.nextWellUrlValue
        }
        break
      case "ArrowUp":
        if (this.prevImageUrlValue) {
          console.log("Navigating to prevImageUrl:", this.prevImageUrlValue)
          window.location.href = this.prevImageUrlValue
        }
        break
      case "ArrowDown":
        if (this.nextImageUrlValue) {
          console.log("Navigating to nextImageUrl:", this.nextImageUrlValue)
          window.location.href = this.nextImageUrlValue
        }
        break
    }
  }

  handleImageClick(e) {
    console.log("handleImageClick called - Controller ID:", this.data.get("controller-id") || "unknown")
    console.log("Event:", e)
    
    const rect = this.imageTarget.getBoundingClientRect()
    const scaleX = this.originalWidthValue / this.imageTarget.clientWidth
    const scaleY = this.originalHeightValue / this.imageTarget.clientHeight
    
    // Calculate click position relative to image
    const x = (e.clientX - rect.left) * scaleX
    const y = (e.clientY - rect.top) * scaleY
    
    // Round to nearest integer pixel
    const pixelX = Math.round(x)
    const pixelY = Math.round(y)
    
    // Get selected point type
    const pointType = document.querySelector('input[name="pointType"]:checked')?.value || 'crystal'
    console.log("Creating point at:", pixelX, pixelY, "type:", pointType)
    
    this.createPoint(pixelX, pixelY, pointType)
  }

  async createPoint(pixelX, pixelY, pointType) {
    try {
      const response = await fetch(`/wells/${this.wellIdValue}/images/${this.imageIdValue}/point_of_interests`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute("content")
        },
        body: JSON.stringify({
          point_of_interest: {
            pixel_x: pixelX,
            pixel_y: pixelY,
            point_type: pointType
          }
        })
      })
      
      if (response.ok) {
        const point = await response.json()
        console.log("Created point:", point)
        this.addPointToDisplay(point)
        this.showNotification(`${pointType.charAt(0).toUpperCase() + pointType.slice(1)} marked at (${pixelX}, ${pixelY})`, "success")
      } else {
        const errorText = await response.text()
        console.error("Server error response:", errorText)
        this.showNotification(`Error: ${errorText}`, "error")
      }
    } catch (error) {
      console.error("Network error creating point:", error)
      this.showNotification(`Network error: ${error.message}`, "error")
    }
  }

  async loadExistingPoints() {
    try {
      const response = await fetch(`/wells/${this.wellIdValue}/images/${this.imageIdValue}/point_of_interests.json`)
      if (response.ok) {
        this.points = await response.json()
        this.refreshDisplay()
      }
    } catch (error) {
      console.error("Error loading points:", error)
    }
  }

  addPointToDisplay(point) {
    this.points.push(point)
    this.refreshDisplay()
  }

  refreshDisplay() {
    this.clearPointMarkers()
    this.points.forEach(point => this.createPointMarker(point))
    this.updatePointsList()
    this.updatePointsTable()
    this.updatePointsCount()
  }

  refreshPointPositions() {
    // Refresh point marker positions when image is resized
    this.refreshDisplay()
  }

  createPointMarker(point) {
    if (!this.pointsVisible) return
    
    const marker = document.createElement("div")
    marker.className = `point-marker point-${point.point_type}`
    marker.dataset.pointId = point.id
    
    // Position the marker
    const scaleX = this.imageTarget.clientWidth / this.originalWidthValue
    const scaleY = this.imageTarget.clientHeight / this.originalHeightValue
    
    const displayX = point.pixel_x * scaleX
    const displayY = point.pixel_y * scaleY
    
    marker.style.left = `${displayX - 6}px` // Center the 12px marker
    marker.style.top = `${displayY - 6}px`
    marker.style.position = "absolute"
    marker.style.width = "12px"
    marker.style.height = "12px"
    marker.style.borderRadius = "50%"
    marker.style.border = "2px solid white"
    marker.style.cursor = "pointer"
    marker.style.pointerEvents = "auto"
    marker.style.zIndex = "10"
    
    // Color coding by type
    const colors = {
      crystal: "#007bff",    // Blue
      particle: "#6c757d",   // Gray
      droplet: "#17a2b8",    // Cyan
      other: "#ffc107"       // Yellow
    }
    marker.style.backgroundColor = colors[point.point_type] || colors.other
    
    // Tooltip
    marker.title = `${point.point_type} at (${point.pixel_x}, ${point.pixel_y})`
    if (point.description) {
      marker.title += ` - ${point.description}`
    }
    
    // Click handler for deletion
    marker.addEventListener("click", (e) => {
      e.stopPropagation()
      this.deletePoint(point)
    })
    
    this.overlayTarget.appendChild(marker)
  }

  clearPointMarkers() {
    if (this.hasOverlayTarget) {
      this.overlayTarget.innerHTML = ""
    }
  }

  updatePointsList() {
    if (!this.hasPointsListTarget) return
    
    if (this.points.length === 0) {
      this.pointsListTarget.style.display = "none"
      return
    }
    
    this.pointsListTarget.style.display = "block"
  }

  updatePointsTable() {
    if (!this.hasPointsTableContainerTarget) return
    
    const table = document.createElement("table")
    table.className = "table table-sm table-striped"
    table.innerHTML = `
      <thead>
        <tr>
          <th>Type</th>
          <th>Pixel Coords</th>
          <th>Real World (mm)</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        ${this.points.map(point => `
          <tr>
            <td><span class="badge bg-${this.getTypeColor(point.point_type)}">${point.point_type}</span></td>
            <td>(${point.pixel_x}, ${point.pixel_y})</td>
            <td>(${this.formatCoordinate(point.real_world_x_mm)}, ${this.formatCoordinate(point.real_world_y_mm)})</td>
            <td>
              <button class="btn btn-outline-danger btn-xs" data-action="click->interactive-image#deletePointById" data-point-id="${point.id}">
                Delete
              </button>
            </td>
          </tr>
        `).join("")}
      </tbody>
    `
    
    this.pointsTableContainerTarget.innerHTML = ""
    this.pointsTableContainerTarget.appendChild(table)
  }

  formatCoordinate(value) {
    if (value === null || value === undefined || isNaN(value)) {
      return "N/A"
    }
    return parseFloat(value).toFixed(3)
  }

  deletePointById(event) {
    const pointId = parseInt(event.currentTarget.dataset.pointId)
    const point = this.points.find(p => p.id === pointId)
    if (point) {
      this.deletePoint(point)
    }
  }

  async deletePoint(point) {
    if (!confirm(`Delete this ${point.point_type}?`)) return
    
    try {
      const response = await fetch(`/wells/${this.wellIdValue}/images/${this.imageIdValue}/point_of_interests/${point.id}`, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute("content")
        }
      })
      
      if (response.ok) {
        this.points = this.points.filter(p => p.id !== point.id)
        this.refreshDisplay()
        this.showNotification("Point deleted", "success")
      } else {
        this.showNotification("Error deleting point", "error")
      }
    } catch (error) {
      console.error("Error deleting point:", error)
      this.showNotification("Network error deleting point", "error")
    }
  }

  updatePointsCount() {
    if (this.hasPointsCountTarget) {
      this.pointsCountTarget.textContent = this.points.length
    }
  }

  getTypeColor(type) {
    const colors = {
      crystal: "primary",
      particle: "secondary", 
      droplet: "info",
      other: "warning"
    }
    return colors[type] || "secondary"
  }

  async clearAllPoints() {
    if (this.points.length === 0) return
    
    if (!confirm(`Delete all ${this.points.length} points?`)) return
    
    try {
      const deletePromises = this.points.map(point => 
        fetch(`/wells/${this.wellIdValue}/images/${this.imageIdValue}/point_of_interests/${point.id}`, {
          method: "DELETE",
          headers: {
            "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute("content")
          }
        })
      )
      
      await Promise.all(deletePromises)
      this.points = []
      this.refreshDisplay()
      this.showNotification("All points cleared", "success")
    } catch (error) {
      console.error("Error clearing points:", error)
      this.showNotification("Error clearing points", "error")
    }
  }

  togglePointsVisibility() {
    this.pointsVisible = !this.pointsVisible
    
    if (this.hasTogglePointsBtnTarget) {
      this.togglePointsBtnTarget.textContent = this.pointsVisible ? "Hide Points" : "Show Points"
    }
    
    if (this.pointsVisible) {
      this.refreshDisplay()
    } else {
      this.clearPointMarkers()
    }
  }

  async autoSegment() {
    if (!this.hasAutoSegmentBtnTarget) return
    
    // Disable button and show loading state
    this.autoSegmentBtnTarget.disabled = true
    const originalText = this.autoSegmentBtnTarget.innerHTML
    this.autoSegmentBtnTarget.innerHTML = '<i class="bi bi-hourglass-split"></i> Queuing...'
    
    try {
      const response = await fetch(`/wells/${this.wellIdValue}/images/${this.imageIdValue}/point_of_interests/auto_segment`, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute("content")
        }
      })
      
      if (response.ok) {
        const result = await response.json()
        
        if (result.status === "queued") {
          // Job was queued, start polling for completion
          this.showNotification(result.message, "info")
          this.autoSegmentBtnTarget.innerHTML = '<i class="bi bi-clock"></i> Processing...'
          this.pollSegmentationStatus()
        } else if (result.points) {
          // Immediate completion (shouldn't happen with queue, but handle it)
          result.points.forEach(point => {
            this.addPointToDisplay(point)
          })
          this.showNotification(
            `Auto-segmentation completed! Created ${result.points.length} points using ${result.model_used} model`, 
            "success"
          )
          this.autoSegmentBtnTarget.disabled = false
          this.autoSegmentBtnTarget.innerHTML = originalText
        }
      } else {
        const errorData = await response.json()
        this.showNotification(`Auto-segmentation failed: ${errorData.error}`, "error")
        this.autoSegmentBtnTarget.disabled = false
        this.autoSegmentBtnTarget.innerHTML = originalText
      }
    } catch (error) {
      console.error("Error during auto-segmentation:", error)
      this.showNotification(`Network error during auto-segmentation: ${error.message}`, "error")
      this.autoSegmentBtnTarget.disabled = false
      this.autoSegmentBtnTarget.innerHTML = originalText
    }
  }

  async pollSegmentationStatus() {
    if (!this.hasAutoSegmentBtnTarget) return
    
    const poll = async () => {
      try {
        const response = await fetch(`/wells/${this.wellIdValue}/images/${this.imageIdValue}/point_of_interests/auto_segment_status`)
        
        if (response.ok) {
          const status = await response.json()
          
          if (status.status === "processing") {
            // Still processing, continue polling
            this.autoSegmentBtnTarget.innerHTML = `<i class="bi bi-arrow-clockwise"></i> Processing... (Queue: ${status.queue_position || 1})`
            setTimeout(poll, 2000) // Poll every 2 seconds
          } else if (status.status === "ready") {
            // Job completed, reload points
            await this.loadExistingPoints()
            this.showNotification("Auto-segmentation completed! Points have been added to the image.", "success")
            this.autoSegmentBtnTarget.disabled = false
            this.autoSegmentBtnTarget.innerHTML = '<i class="bi bi-magic"></i> Auto Segment'
          }
        } else {
          throw new Error("Failed to check segmentation status")
        }
      } catch (error) {
        console.error("Error polling segmentation status:", error)
        this.showNotification("Error checking segmentation status", "error")
        this.autoSegmentBtnTarget.disabled = false
        this.autoSegmentBtnTarget.innerHTML = '<i class="bi bi-magic"></i> Auto Segment'
      }
    }
    
    // Start polling after a short delay
    setTimeout(poll, 1000)
  }

  showNotification(message, type = "info") {
    // Create a simple notification
    const notification = document.createElement("div")
    notification.className = `alert alert-${type === "error" ? "danger" : "success"} alert-dismissible fade show position-fixed`
    notification.style.top = "20px"
    notification.style.right = "20px"
    notification.style.zIndex = "9999"
    notification.innerHTML = `
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `
    
    document.body.appendChild(notification)
    
    // Auto remove after 5 seconds
    setTimeout(() => {
      if (notification.parentNode) {
        notification.remove()
      }
    }, 5000)
  }
}