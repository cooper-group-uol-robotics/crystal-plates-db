import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="well-content-form"
export default class extends Controller {
    static targets = [
        "contentType",
        "stockSolutionSelect",
        "stockSolutionSearch",
        "stockSolutionResults",
        "stockSolutionVolume",
        "chemicalSelect",
        "chemicalSearch",
        "chemicalVolume",
        "chemicalResults",
        "stockSolutionFields",
        "chemicalFields"
    ]

    static values = {
        chemicalSearchUrl: String,
        stockSolutionSearchUrl: String,
        wellId: Number
    }

    connect() {
        console.log("WellContentForm controller connected")
        this.toggleContentFields()

        // Add click outside handlers to close dropdowns
        this.boundCloseDropdowns = this.closeDropdowns.bind(this)
        document.addEventListener('click', this.boundCloseDropdowns)
    }

    // Handle content type selection change
    contentTypeChanged() {
        this.toggleContentFields()
        this.clearSelections()
    }

    toggleContentFields() {
        const contentType = this.contentTypeTarget.value

        if (contentType === "stock_solution") {
            this.stockSolutionFieldsTarget.style.display = "block"
            this.chemicalFieldsTarget.style.display = "none"
        } else if (contentType === "chemical") {
            this.stockSolutionFieldsTarget.style.display = "none"
            this.chemicalFieldsTarget.style.display = "block"
        } else {
            this.stockSolutionFieldsTarget.style.display = "none"
            this.chemicalFieldsTarget.style.display = "none"
        }
    }

    clearSelections() {
        // Clear stock solution selection
        if (this.hasStockSolutionSelectTarget) {
            this.stockSolutionSelectTarget.value = ""
        }
        if (this.hasStockSolutionSearchTarget) {
            this.stockSolutionSearchTarget.value = ""
        }
        if (this.hasStockSolutionResultsTarget) {
            this.stockSolutionResultsTarget.style.display = "none"
            this.stockSolutionResultsTarget.innerHTML = ""
        }

        // Clear chemical selection
        if (this.hasChemicalSelectTarget) {
            this.chemicalSelectTarget.value = ""
        }
        if (this.hasChemicalSearchTarget) {
            this.chemicalSearchTarget.value = ""
        }
        if (this.hasChemicalResultsTarget) {
            this.chemicalResultsTarget.style.display = "none"
            this.chemicalResultsTarget.innerHTML = ""
        }
    }



    // Handle stock solution search as user types
    searchStockSolutions() {
        const query = this.stockSolutionSearchTarget.value.trim()

        if (query.length < 2) {
            this.stockSolutionResultsTarget.style.display = "none"
            this.stockSolutionResultsTarget.innerHTML = ""
            return
        }

        // Debounce the search
        clearTimeout(this.stockSolutionSearchTimeout)
        this.stockSolutionSearchTimeout = setTimeout(() => {
            this.performStockSolutionSearch(query)
        }, 300)
    }

    // Handle chemical search as user types
    searchChemicals() {
        const query = this.chemicalSearchTarget.value.trim()

        if (query.length < 2) {
            this.chemicalResultsTarget.style.display = "none"
            this.chemicalResultsTarget.innerHTML = ""
            return
        }

        // Debounce the search
        clearTimeout(this.chemicalSearchTimeout)
        this.chemicalSearchTimeout = setTimeout(() => {
            this.performChemicalSearch(query)
        }, 300)
    }

    async performStockSolutionSearch(query) {
        try {
            const url = `${this.stockSolutionSearchUrlValue}?q=${encodeURIComponent(query)}`
            const response = await fetch(url, {
                headers: {
                    "Accept": "application/json",
                    "X-Requested-With": "XMLHttpRequest"
                }
            })

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`)
            }

            const stockSolutions = await response.json()
            this.displayStockSolutionResults(stockSolutions)
        } catch (error) {
            console.error("Stock solution search failed:", error)
            this.stockSolutionResultsTarget.innerHTML = `
        <div class="search-result-item text-danger">
          Search failed. Please try again.
        </div>
      `
            this.stockSolutionResultsTarget.style.display = "block"
        }
    }

    async performChemicalSearch(query) {
        try {
            const url = `${this.chemicalSearchUrlValue}?q=${encodeURIComponent(query)}`
            const response = await fetch(url, {
                headers: {
                    "Accept": "application/json",
                    "X-Requested-With": "XMLHttpRequest"
                }
            })

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`)
            }

            const chemicals = await response.json()
            this.displayChemicalResults(chemicals)
        } catch (error) {
            console.error("Chemical search failed:", error)
            this.chemicalResultsTarget.innerHTML = `
        <div class="search-result-item text-danger">
          Search failed. Please try again.
        </div>
      `
            this.chemicalResultsTarget.style.display = "block"
        }
    }

    displayStockSolutionResults(stockSolutions) {
        if (stockSolutions.length === 0) {
            this.stockSolutionResultsTarget.innerHTML = `
        <div class="search-result-item text-muted">No stock solutions found</div>
      `
            this.stockSolutionResultsTarget.style.display = "block"
            return
        }

        const resultHtml = stockSolutions.map(stockSolution => `
      <div class="search-result-item" 
           data-action="click->well-content-form#selectStockSolution"
           data-stock-solution-id="${stockSolution.id}"
           data-stock-solution-name="${this.escapeHtml(stockSolution.display_name || stockSolution.name)}">
        <div class="fw-semibold">${this.escapeHtml(stockSolution.display_name || stockSolution.name)}</div>
        ${stockSolution.component_summary ? `<small class="text-muted">${this.escapeHtml(stockSolution.component_summary)}</small>` : ''}
      </div>
    `).join('')

        this.stockSolutionResultsTarget.innerHTML = resultHtml
        this.stockSolutionResultsTarget.style.display = "block"
    }

    displayChemicalResults(chemicals) {
        if (chemicals.length === 0) {
            this.chemicalResultsTarget.innerHTML = `
        <div class="search-result-item text-muted">No chemicals found</div>
      `
            this.chemicalResultsTarget.style.display = "block"
            return
        }

        const resultHtml = chemicals.map(chemical => `
      <div class="search-result-item" 
           data-action="click->well-content-form#selectChemical"
           data-chemical-id="${chemical.id}"
           data-chemical-name="${this.escapeHtml(chemical.name)}">
        <div class="fw-semibold">${this.escapeHtml(chemical.name)}</div>
        ${chemical.cas ? `<small class="text-muted">CAS: ${this.escapeHtml(chemical.cas)}</small>` : ''}
        ${chemical.storage ? `<small class="text-muted d-block">Storage: ${this.escapeHtml(chemical.storage)}</small>` : ''}
      </div>
    `).join('')

        this.chemicalResultsTarget.innerHTML = resultHtml
        this.chemicalResultsTarget.style.display = "block"
    }

    selectStockSolution(event) {
        const stockSolutionId = event.currentTarget.dataset.stockSolutionId
        const stockSolutionName = event.currentTarget.dataset.stockSolutionName

        console.log('Selecting stock solution:', { stockSolutionId, stockSolutionName })
        console.log('stockSolutionSelectTarget element:', this.stockSolutionSelectTarget)
        console.log('stockSolutionSelectTarget type:', this.stockSolutionSelectTarget.type)

        // Set the hidden stock solution select value
        this.stockSolutionSelectTarget.value = stockSolutionId

        // Update the search field to show selected stock solution
        this.stockSolutionSearchTarget.value = stockSolutionName

        // Hide search results
        this.stockSolutionResultsTarget.style.display = "none"
        this.stockSolutionResultsTarget.innerHTML = ""

        console.log('Stock solution selected, hidden field value:', this.stockSolutionSelectTarget.value)
        console.log('Hidden field element after setting:', this.stockSolutionSelectTarget)
    }

    selectChemical(event) {
        const chemicalId = event.currentTarget.dataset.chemicalId
        const chemicalName = event.currentTarget.dataset.chemicalName

        console.log('Selecting chemical:', { chemicalId, chemicalName })

        // Set the hidden chemical select value
        this.chemicalSelectTarget.value = chemicalId

        // Update the search field to show selected chemical
        this.chemicalSearchTarget.value = chemicalName

        // Hide search results
        this.chemicalResultsTarget.style.display = "none"
        this.chemicalResultsTarget.innerHTML = ""

        console.log('Chemical selected, hidden field value:', this.chemicalSelectTarget.value)
    }

    // Form submission handling
    async submitContent(event) {
        event.preventDefault()

        const contentType = this.contentTypeTarget.value

        // Validate and prepare form data
        if (!this.prepareFormSubmission(contentType)) {
            return
        }

        const formData = new FormData(event.target)

        try {
            const response = await fetch(event.target.action, {
                method: 'POST',
                body: formData,
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                }
            })

            if (response.ok) {
                // Success - reload the page to update the content display
                window.location.reload()
            } else {
                const errorText = await response.text()
                this.showError("Failed to add content. Please try again.")
            }
        } catch (error) {
            console.error("Content submission failed:", error)
            this.showError("Network error. Please check your connection and try again.")
        }
    }

    prepareFormSubmission(contentType) {
        // Get volume input based on content type
        let volume, contentId, contentableType

        if (contentType === 'stock_solution') {
            volume = this.hasStockSolutionVolumeTarget ? this.stockSolutionVolumeTarget.value.trim() : ''
            contentId = this.hasStockSolutionSelectTarget ? this.stockSolutionSelectTarget.value : ''

            if (!contentId) {
                this.showError("Please select a stock solution")
                return false
            }

            // For stock solutions, we still use the old association for backward compatibility
            // The controller will handle this properly
            contentableType = 'StockSolution'
        } else if (contentType === 'chemical') {
            volume = this.hasChemicalVolumeTarget ? this.chemicalVolumeTarget.value.trim() : ''
            contentId = this.hasChemicalSelectTarget ? this.chemicalSelectTarget.value : ''
            contentableType = 'Chemical'

            if (!contentId) {
                this.showError("Please select a chemical")
                return false
            }
        } else {
            this.showError("Please select a content type")
            return false
        }

        if (!volume) {
            this.showError("Please enter a volume/amount with unit (e.g., 50 μL, 10 mg)")
            return false
        }

        // Find hidden form fields within this controller's element scope
        const contentableTypeField = this.element.querySelector('#contentable_type')
        const contentableIdField = this.element.querySelector('#contentable_id')
        const formVolumeField = this.element.querySelector('#form_volume')

        console.log('Setting form fields:', {
            contentableType,
            contentId,
            volume,
            contentableTypeField: !!contentableTypeField,
            contentableIdField: !!contentableIdField,
            formVolumeField: !!formVolumeField
        })

        // Set hidden form fields
        if (contentableTypeField) {
            contentableTypeField.value = contentableType
        } else {
            console.error('contentable_type field not found')
        }

        if (contentableIdField) {
            contentableIdField.value = contentId
        } else {
            console.error('contentable_id field not found')
        }

        if (formVolumeField) {
            formVolumeField.value = volume
        } else {
            console.error('form_volume field not found')
        }

        return true
    }



    showError(message) {
        // Find or create an error container
        let errorContainer = document.querySelector('.well-content-errors')
        if (!errorContainer) {
            errorContainer = document.createElement('div')
            errorContainer.className = 'alert alert-danger well-content-errors mt-2'
            this.element.prepend(errorContainer)
        }

        errorContainer.textContent = message

        // Auto-hide after 5 seconds
        setTimeout(() => {
            errorContainer.remove()
        }, 5000)
    }

    escapeHtml(text) {
        const div = document.createElement('div')
        div.textContent = text
        return div.innerHTML
    }

    closeDropdowns(event) {
        // Close stock solution dropdown if click is outside
        if (this.hasStockSolutionSearchTarget && this.hasStockSolutionResultsTarget) {
            if (!this.stockSolutionSearchTarget.contains(event.target) &&
                !this.stockSolutionResultsTarget.contains(event.target)) {
                this.stockSolutionResultsTarget.style.display = "none"
            }
        }

        // Close chemical dropdown if click is outside
        if (this.hasChemicalSearchTarget && this.hasChemicalResultsTarget) {
            if (!this.chemicalSearchTarget.contains(event.target) &&
                !this.chemicalResultsTarget.contains(event.target)) {
                this.chemicalResultsTarget.style.display = "none"
            }
        }
    }

    // Remove individual well content
    async removeContent(event) {
        const contentId = event.currentTarget.dataset.contentId
        const wellId = this.wellIdValue

        if (!confirm('Are you sure you want to remove this content from the well?')) {
            return
        }

        try {
            const response = await fetch(`/wells/${wellId}/well_contents/${contentId}`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                }
            })

            if (response.ok) {
                // Reload the page to update the content display
                window.location.reload()
            } else {
                this.showError('Error removing content. Please try again.')
            }
        } catch (error) {
            console.error('Error:', error)
            this.showError('Error removing content. Please check your connection and try again.')
        }
    }

    // Remove all well content
    async removeAllContent(event) {
        const wellId = this.wellIdValue

        if (!confirm('Are you sure you want to remove all content from this well?')) {
            return
        }

        try {
            const response = await fetch(`/wells/${wellId}/well_contents/destroy_all`, {
                method: 'DELETE',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                }
            })

            if (response.ok) {
                // Reload the page to update the content display
                window.location.reload()
            } else {
                this.showError('Error removing content. Please try again.')
            }
        } catch (error) {
            console.error('Error:', error)
            this.showError('Error removing content. Please check your connection and try again.')
        }
    }

    disconnect() {
        // Clean up event listeners
        if (this.boundCloseDropdowns) {
            document.removeEventListener('click', this.boundCloseDropdowns)
        }

        // Clean up any timeouts
        if (this.chemicalSearchTimeout) {
            clearTimeout(this.chemicalSearchTimeout)
        }
        if (this.stockSolutionSearchTimeout) {
            clearTimeout(this.stockSolutionSearchTimeout)
        }
    }
}