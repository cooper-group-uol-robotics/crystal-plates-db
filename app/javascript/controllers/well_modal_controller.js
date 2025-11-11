import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="well-modal"
export default class extends Controller {
    static targets = ["modal", "title", "contentForm", "imagesContent", "pxrdContent", "scxrdContent", "calorimetryContent", "customAttributesContent"]
    static values = {
        wellId: Number,
        wellLabel: String,
        plateBarcode: String
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
        // Only handle events from the actual well modal, not nested modals
        if (event.target !== this.modalTarget) {
            console.log("Ignoring modal shown event from nested modal:", event.target.id)
            return
        }

        console.log("Well modal shown event:", event)

        // Get the button that triggered the modal
        const triggerButton = event.relatedTarget
        console.log("Trigger button:", triggerButton)

        if (triggerButton) {
            // Extract well information from the button's data attributes
            const wellId = triggerButton.getAttribute('data-well-id')
            const wellLabel = triggerButton.getAttribute('data-well-label')

            // Find the plate barcode from the closest plate container or URL
            const plateBarcode = this.extractPlateBarcode(triggerButton)

            console.log("Extracted from button - wellId:", wellId, "wellLabel:", wellLabel, "plateBarcode:", plateBarcode)

            // Set the controller values
            this.wellIdValue = parseInt(wellId) || 0
            this.wellLabelValue = wellLabel || ''
            this.plateBarcodeValue = plateBarcode || ''
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
            // Load images in background
            this.loadImagesInBackground()
            // Set up placeholder content for PXRD, SCXRD, calorimetry, and custom attributes tabs
            this.setupPxrdPlaceholder()
            this.setupScxrdPlaceholder()
            this.setupCalorimetryPlaceholder()
            this.setupCustomAttributesPlaceholder()

            // Load calorimetry data in background (this was working before)
            this.loadCalorimetryInBackground()
            // Note: Custom attributes will be loaded on tab click for better UX
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
        // Only handle events from the actual well modal, not nested modals
        if (event.target !== this.modalTarget) {
            console.log("Ignoring modal hidden event from nested modal:", event.target.id)
            return
        }

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

            // Execute any script tags in the loaded content
            this.executeScripts(this.imagesContentTarget)

            // Process the new content to ensure Stimulus controllers are connected
            this.processNewContent(this.imagesContentTarget)
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
            this.pxrdContentTarget.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading PXRD patterns...</span>
          </div>
          <div class="text-muted">Loading PXRD patterns...</div>
        </div>
      `

            console.log("Fetching PXRD data for well:", this.wellIdValue)
            const response = await fetch(`/wells/${this.wellIdValue}/pxrd_patterns`)

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`)
            }

            const html = await response.text()
            console.log("PXRD data loaded successfully")

            this.pxrdContentTarget.innerHTML = html

            // Execute any script tags in the loaded content
            this.executeScripts(this.pxrdContentTarget)

            // Process the new content to ensure Stimulus controllers are connected
            this.processNewContent(this.pxrdContentTarget)
        } catch (error) {
            console.error("Failed to load PXRD data:", error)
            this.pxrdContentTarget.innerHTML = `
        <div class="alert alert-warning">
          Failed to load PXRD patterns: ${error.message}
        </div>
      `
        }
    }

    // Load SCXRD data in background
    async loadScxrdInBackground() {
        if (!this.hasScxrdContentTarget || !this.wellIdValue) return

        try {
            this.scxrdContentTarget.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading SCXRD datasets...</span>
          </div>
          <div class="text-muted">Loading SCXRD datasets...</div>
        </div>
      `

            console.log("Fetching SCXRD data for well:", this.wellIdValue)
            const response = await fetch(`/wells/${this.wellIdValue}/scxrd_datasets`)

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`)
            }

            const html = await response.text()
            console.log("SCXRD data loaded successfully")

            this.scxrdContentTarget.innerHTML = html

            // Execute any script tags in the loaded content
            this.executeScripts(this.scxrdContentTarget)

            // Process the new content to ensure Stimulus controllers are connected
            this.processNewContent(this.scxrdContentTarget)
        } catch (error) {
            console.error("Failed to load SCXRD data:", error)
            this.scxrdContentTarget.innerHTML = `
        <div class="alert alert-warning">
          Failed to load SCXRD datasets: ${error.message}
        </div>
      `
        }
    }

    // Load Calorimetry data in background
    async loadCalorimetryInBackground() {
        if (!this.hasCalorimetryContentTarget || !this.wellIdValue) return

        try {
            this.calorimetryContentTarget.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading calorimetry datasets...</span>
          </div>
          <div class="text-muted">Loading calorimetry datasets...</div>
        </div>
      `

            console.log("Fetching calorimetry data for well:", this.wellIdValue)
            const response = await fetch(`/wells/${this.wellIdValue}/calorimetry_datasets`)

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`)
            }

            const html = await response.text()
            console.log("Calorimetry data loaded successfully")

            this.calorimetryContentTarget.innerHTML = html

            // Execute any script tags in the loaded content
            this.executeScripts(this.calorimetryContentTarget)

            // Process the new content to ensure Stimulus controllers are connected
            this.processNewContent(this.calorimetryContentTarget)
        } catch (error) {
            console.error("Failed to load calorimetry data:", error)
            this.calorimetryContentTarget.innerHTML = `
        <div class="alert alert-warning">
          Failed to load calorimetry datasets: ${error.message}
        </div>
      `
        }
    }

    // Set up PXRD placeholder content
    setupPxrdPlaceholder() {
        if (!this.hasPxrdContentTarget) return

        this.pxrdContentTarget.innerHTML = `
      <div class="text-center text-muted py-4">
        <i class="fas fa-chart-line fa-3x mb-3 text-secondary"></i>
        <div class="h5">PXRD Patterns</div>
        <div>Click to load powder X-ray diffraction patterns for this well</div>
      </div>
    `
    }

    // Set up SCXRD placeholder content
    setupScxrdPlaceholder() {
        if (!this.hasScxrdContentTarget) return

        this.scxrdContentTarget.innerHTML = `
      <div class="text-center text-muted py-4">
        <i class="fas fa-atom fa-3x mb-3 text-secondary"></i>
        <div class="h5">SCXRD Datasets</div>
        <div>Click to load single crystal X-ray diffraction datasets for this well</div>
      </div>
    `
    }

    // Set up Calorimetry placeholder content
    setupCalorimetryPlaceholder() {
        if (!this.hasCalorimetryContentTarget) return

        this.calorimetryContentTarget.innerHTML = `
      <div class="text-center text-muted py-4">
        <i class="fas fa-thermometer-half fa-3x mb-3 text-secondary"></i>
        <div class="h5">Calorimetry Data</div>
        <div>Click to load calorimetry datasets for this well</div>
      </div>
    `
    }

    // Set up Custom Attributes placeholder content
    setupCustomAttributesPlaceholder() {
        if (!this.hasCustomAttributesContentTarget) return

        this.customAttributesContentTarget.innerHTML = `
      <div class="text-center text-muted py-4">
        <i class="fas fa-tags fa-3x mb-3 text-secondary"></i>
        <div class="h5">Custom Attributes</div>
        <div>Click to load custom attributes for this well</div>
      </div>
    `
    }

    // Load Custom Attributes data in background
    async loadCustomAttributesInBackground() {
        if (!this.hasCustomAttributesContentTarget || !this.wellIdValue) return

        try {
            this.customAttributesContentTarget.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading custom attributes...</span>
          </div>
          <div class="text-muted">Loading custom attributes...</div>
        </div>
      `

            console.log("Fetching custom attributes data for well:", this.wellIdValue)
            const response = await fetch(`/wells/${this.wellIdValue}/custom_attributes`)

            if (!response.ok) {
                throw new Error(`HTTP ${response.status}: ${response.statusText}`)
            }

            const html = await response.text()
            console.log("Custom attributes data loaded successfully")

            this.customAttributesContentTarget.innerHTML = html

            // Execute any script tags in the loaded content
            this.executeScripts(this.customAttributesContentTarget)

            // Process the new content to ensure Stimulus controllers are connected
            this.processNewContent(this.customAttributesContentTarget)
        } catch (error) {
            console.error("Failed to load custom attributes data:", error)
            this.customAttributesContentTarget.innerHTML = `
        <div class="alert alert-warning">
          Failed to load custom attributes: ${error.message}
        </div>
      `
        }
    }

    // Helper method to extract plate barcode
    extractPlateBarcode() {
        // Try to get plate barcode from URL path
        const pathMatch = window.location.pathname.match(/\/plates\/([^\/]+)/)
        if (pathMatch) {
            return pathMatch[1]
        }

        // Fallback: look for plate data in DOM
        const plateElement = document.querySelector('[data-plate-barcode]')
        if (plateElement) {
            return plateElement.getAttribute('data-plate-barcode')
        }

        return null
    }

    // Execute script tags in dynamically loaded content
    executeScripts(container) {
        const scripts = container.querySelectorAll('script')
        scripts.forEach(script => {
            try {
                if (script.type === 'module' || script.type === 'text/javascript' || !script.type) {
                    // Create a new script element to ensure proper execution
                    const newScript = document.createElement('script')

                    if (script.type) {
                        newScript.type = script.type
                    }

                    if (script.src) {
                        // For external scripts
                        newScript.src = script.src
                        newScript.async = true
                    } else {
                        // For inline scripts
                        newScript.textContent = script.innerHTML
                    }

                    // Add to head to execute, then remove
                    document.head.appendChild(newScript)

                    // Clean up after execution (slight delay for modules)
                    setTimeout(() => {
                        if (newScript.parentNode) {
                            newScript.parentNode.removeChild(newScript)
                        }
                    }, script.type === 'module' ? 1000 : 100)
                }
            } catch (error) {
                console.error('Error executing script in loaded content:', error, script)
            }
        })
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
        if (this.hasCalorimetryContentTarget) {
            this.calorimetryContentTarget.innerHTML = ""
        }
        if (this.hasCustomAttributesContentTarget) {
            this.customAttributesContentTarget.innerHTML = ""
        }

        // Reset values
        this.wellIdValue = null
        this.wellLabelValue = ""
        this.plateBarcodeValue = ""
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
                // Load PXRD data when tab is clicked if not already loaded
                if (!this.pxrdContentTarget.innerHTML.trim() ||
                    this.pxrdContentTarget.innerHTML.includes('Click to load powder') ||
                    this.pxrdContentTarget.innerHTML.includes('spinner-border')) {
                    this.loadPxrdInBackground()
                }
                break
            case 'scxrd':
                // Load SCXRD data when tab is clicked if not already loaded
                if (!this.scxrdContentTarget.innerHTML.trim() ||
                    this.scxrdContentTarget.innerHTML.includes('Click to load single crystal') ||
                    this.scxrdContentTarget.innerHTML.includes('spinner-border')) {
                    this.loadScxrdInBackground()
                }
                break
            case 'calorimetry':
                // Load calorimetry data when tab is clicked if not already loaded
                if (!this.calorimetryContentTarget.innerHTML.trim() ||
                    this.calorimetryContentTarget.innerHTML.includes('Click to load calorimetry datasets') ||
                    this.calorimetryContentTarget.innerHTML.includes('spinner-border')) {
                    this.loadCalorimetryInBackground()
                }
                break
            case 'custom-attributes':
                // Load custom attributes data when tab is clicked if not already loaded
                if (!this.customAttributesContentTarget.innerHTML.trim() ||
                    this.customAttributesContentTarget.innerHTML.includes('Click to load custom attributes') ||
                    this.customAttributesContentTarget.innerHTML.includes('spinner-border')) {
                    this.loadCustomAttributesInBackground()
                }
                break
        }
    }

    // Process new content to ensure Stimulus controllers are connected
    processNewContent(container) {
        // Multiple approaches to ensure Stimulus detects new controllers
        if (window.Stimulus) {
            try {
                // Method 1: Use application.elementObserver if available (Stimulus 3.x)
                if (window.Stimulus.elementObserver && window.Stimulus.elementObserver.processTree) {
                    window.Stimulus.elementObserver.processTree(container)
                }
                // Method 2: Use application.start() which should scan for new elements
                else if (window.Stimulus.start) {
                    // This will re-scan the entire document, less efficient but more reliable
                    window.Stimulus.start()
                }
                // Method 3: Try to manually trigger controller detection
                else if (window.Stimulus.application) {
                    // Dispatch a custom event to trigger Stimulus to re-scan
                    container.dispatchEvent(new CustomEvent('stimulus:load', { bubbles: true }))
                }

                console.log("Processed new content for Stimulus controllers")
            } catch (error) {
                console.warn("Error processing new content for Stimulus:", error)
            }
        } else {
            console.warn("Stimulus not available for processing new content")
        }
    }
}