import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="well-modal"
export default class extends Controller {
    static targets = ["modal", "title", "contentForm", "imagesContent", "pxrdContent", "scxrdContent"]
    static values = {
        wellId: Number,
        wellLabel: String
    }

    connect() {
        console.log("Well modal controller connected")

        // Set up modal event listeners
        if (this.hasModalTarget) {
            this.modalTarget.addEventListener('shown.bs.modal', this.onModalShown.bind(this))
            this.modalTarget.addEventListener('hidden.bs.modal', this.onModalHidden.bind(this))
        }
    }

    disconnect() {
        // Clean up event listeners
        if (this.hasModalTarget) {
            this.modalTarget.removeEventListener('shown.bs.modal', this.onModalShown.bind(this))
            this.modalTarget.removeEventListener('hidden.bs.modal', this.onModalHidden.bind(this))
        }
    }

    // Called when modal is shown
    onModalShown(event) {
        console.log("Well modal shown event:", event)

        // Get the button that triggered the modal
        const triggerButton = event.relatedTarget
        console.log("Trigger button:", triggerButton)

        if (triggerButton) {
            // Extract well information from the button's data attributes
            const wellId = triggerButton.getAttribute('data-well-id')
            const wellLabel = triggerButton.getAttribute('data-well-label')

            console.log("Extracted from button - wellId:", wellId, "wellLabel:", wellLabel)

            // Set the controller values
            this.wellIdValue = parseInt(wellId) || 0
            this.wellLabelValue = wellLabel || ''
        }

        console.log("Well modal shown for well:", this.wellIdValue, "type:", typeof this.wellIdValue)

        // Update modal title
        if (this.hasTitleTarget && this.wellLabelValue) {
            this.titleTarget.textContent = `Well ${this.wellLabelValue} Details`
        }

        // Ensure content tab is active by default
        this.activateContentTab()

        // Load content form immediately if we have a valid well ID
        const wellId = parseInt(this.wellIdValue)
        console.log("Parsed well ID:", wellId, "original:", this.wellIdValue)

        if (wellId && wellId > 0) {
            this.loadContentForm()
            // Load other tabs in background
            this.loadImagesInBackground()
            this.loadPxrdInBackground()
            this.loadScxrdInBackground()
        } else {
            console.error("Invalid well ID for loading content:", this.wellIdValue)
            if (this.hasContentFormTarget) {
                this.contentFormTarget.innerHTML = `
          <div class="alert alert-warning">
            Invalid well selected. Well ID: ${this.wellIdValue}
          </div>
        `
            }
        }
    }

    // Called when modal is hidden
    onModalHidden(event) {
        console.log("Well modal hidden")
        this.resetModal()
    }

    // Show modal with specific well data
    show(wellId, wellLabel) {
        this.wellIdValue = wellId
        this.wellLabelValue = wellLabel

        // Show the modal using Bootstrap
        const modal = new bootstrap.Modal(this.modalTarget)
        modal.show()
    }

    // Activate the content tab
    activateContentTab() {
        const contentTab = document.getElementById('content-tab')
        const contentPane = document.getElementById('content')
        const allTabs = document.querySelectorAll('#wellTabs .nav-link')
        const allPanes = document.querySelectorAll('#wellTabContent .tab-pane')

        // Remove active class from all tabs and panes
        allTabs.forEach(tab => {
            tab.classList.remove('active')
            tab.setAttribute('aria-selected', 'false')
        })
        allPanes.forEach(pane => {
            pane.classList.remove('show', 'active')
        })

        // Activate content tab
        if (contentTab && contentPane) {
            contentTab.classList.add('active')
            contentTab.setAttribute('aria-selected', 'true')
            contentPane.classList.add('show', 'active')
        }
    }

    // Load content form
    async loadContentForm() {
        console.log("loadContentForm called, wellIdValue:", this.wellIdValue)

        if (!this.hasContentFormTarget) {
            console.error("Content form target not found")
            return
        }

        if (!this.wellIdValue || this.wellIdValue === 0) {
            console.error("Invalid well ID:", this.wellIdValue)
            this.contentFormTarget.innerHTML = `
        <div class="alert alert-warning">
          No well selected. Please select a well to view contents.
        </div>
      `
            return
        }

        try {
            this.contentFormTarget.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading content...</span>
          </div>
          <div class="text-muted">Loading well contents...</div>
        </div>
      `

            console.log("Fetching content for well:", this.wellIdValue)
            const response = await fetch(`/wells/${this.wellIdValue}/content_form`)

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`)
            }

            const html = await response.text()
            console.log("Content loaded successfully")

            this.contentFormTarget.innerHTML = html
        } catch (error) {
            console.error("Failed to load content form:", error)
            this.contentFormTarget.innerHTML = `
        <div class="alert alert-danger">
          Failed to load well contents: ${error.message}
        </div>
      `
        }
    }

    // Load images in background
    async loadImagesInBackground() {
        console.log("loadImagesInBackground called, wellIdValue:", this.wellIdValue)

        if (!this.hasImagesContentTarget) {
            console.error("Images content target not found")
            return
        }

        if (!this.wellIdValue || this.wellIdValue === 0) {
            console.log("Skipping image load - no valid well ID")
            return
        }

        try {
            this.imagesContentTarget.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading images...</span>
          </div>
          <div class="text-muted">Loading well images...</div>
        </div>
      `

            const response = await fetch(`/wells/${this.wellIdValue}/images`)

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`)
            }

            const html = await response.text()
            console.log("Images loaded successfully")

            this.imagesContentTarget.innerHTML = html
        } catch (error) {
            console.error("Failed to load images:", error)
            this.imagesContentTarget.innerHTML = `
        <div class="alert alert-warning">
          Failed to load images: ${error.message}
        </div>
      `
        }
    }

    // Load PXRD data in background
    async loadPxrdInBackground() {
        if (!this.hasPxrdContentTarget || !this.wellIdValue) return

        try {
            // This would need to be implemented in the controller
            // For now, just show a placeholder
            this.pxrdContentTarget.innerHTML = `
        <div class="text-center text-muted py-4">
          <i class="fas fa-chart-line fa-2x mb-2"></i>
          <div>PXRD data will be loaded when tab is selected</div>
        </div>
      `
        } catch (error) {
            console.error("Failed to load PXRD data:", error)
        }
    }

    // Load SCXRD data in background
    async loadScxrdInBackground() {
        if (!this.hasScxrdContentTarget || !this.wellIdValue) return

        try {
            // This would need to be implemented in the controller
            // For now, just show a placeholder
            this.scxrdContentTarget.innerHTML = `
        <div class="text-center text-muted py-4">
          <i class="fas fa-atom fa-2x mb-2"></i>
          <div>SCXRD data will be loaded when tab is selected</div>
        </div>
      `
        } catch (error) {
            console.error("Failed to load SCXRD data:", error)
        }
    }

    // Reset modal content
    resetModal() {
        // Clear all content
        if (this.hasContentFormTarget) {
            this.contentFormTarget.innerHTML = ""
        }
        if (this.hasImagesContentTarget) {
            this.imagesContentTarget.innerHTML = ""
        }
        if (this.hasPxrdContentTarget) {
            this.pxrdContentTarget.innerHTML = ""
        }
        if (this.hasScxrdContentTarget) {
            this.scxrdContentTarget.innerHTML = ""
        }

        // Reset values
        this.wellIdValue = null
        this.wellLabelValue = ""
    }

    // Handle tab clicks (if needed for lazy loading)
    handleTabClick(event) {
        const tabId = event.currentTarget.getAttribute('aria-controls')

        switch (tabId) {
            case 'images':
                if (!this.imagesContentTarget.innerHTML.trim() ||
                    this.imagesContentTarget.innerHTML.includes('spinner-border')) {
                    this.loadImagesInBackground()
                }
                break
            case 'pxrd':
                // Load PXRD data when tab is clicked
                break
            case 'scxrd':
                // Load SCXRD data when tab is clicked
                break
        }
    }
}