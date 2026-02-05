import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="bulk-well-content-form"
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
        "chemicalFields",
        "messages"
    ]

    static values = {
        chemicalSearchUrl: String,
        stockSolutionSearchUrl: String,
        wellIds: Array
    }

    connect() {
        console.log("BulkWellContentForm controller connected")
        this.toggleContentFields()

        // Add click outside handlers to close dropdowns
        this.boundCloseDropdowns = this.closeDropdowns.bind(this)
        document.addEventListener('click', this.boundCloseDropdowns)

        // Listen for well IDs being set
        this.element.addEventListener('wellIdsSet', (event) => {
            this.setWellIds(event.detail.wellIds)
        })

        // Check if well IDs are already in data attribute
        if (this.element.dataset.wellIds) {
            try {
                const wellIds = JSON.parse(this.element.dataset.wellIds)
                this.setWellIds(wellIds)
            } catch (error) {
                console.error('Error parsing well IDs from data attribute:', error)
            }
        }
    }

    // Set the well IDs for bulk operations (called from plates_show.js)
    setWellIds(wellIds) {
        this.wellIdsValue = wellIds
        console.log("Well IDs set for bulk operation:", wellIds)
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

        // Clear messages
        this.clearMessages()
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
           data-action="click->bulk-well-content-form#selectStockSolution"
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
           data-action="click->bulk-well-content-form#selectChemical"
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

        // Set the hidden stock solution select value
        this.stockSolutionSelectTarget.value = stockSolutionId

        // Update the search field to show selected stock solution
        this.stockSolutionSearchTarget.value = stockSolutionName

        // Hide search results
        this.stockSolutionResultsTarget.style.display = "none"
        this.stockSolutionResultsTarget.innerHTML = ""
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
    }

    // Handle bulk content submission
    async submitContent(event) {
        event.preventDefault()

        const contentType = this.contentTypeTarget.value

        if (!this.wellIdsValue || this.wellIdsValue.length === 0) {
            this.showError("No wells selected for bulk operation")
            return
        }

        // Validate and prepare form data
        const formData = this.prepareFormData(contentType)
        if (!formData) {
            return
        }

        try {
            const response = await fetch('/wells/bulk_add_content', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
                },
                body: JSON.stringify(formData)
            })

            const result = await response.json()

            if (response.ok && result.status === 'success') {
                this.showSuccess(result.message)
                // Clear the form after successful submission
                this.clearSelections()

                // Optionally refresh the plate view
                setTimeout(() => {
                    window.location.reload()
                }, 2000)
            } else {
                this.showError(result.message || "Failed to add content. Please try again.")
            }
        } catch (error) {
            console.error("Bulk content submission failed:", error)
            this.showError("Network error. Please check your connection and try again.")
        }
    }

    prepareFormData(contentType) {
        let volume, contentId, contentableType

        if (contentType === 'stock_solution') {
            volume = this.hasStockSolutionVolumeTarget ? this.stockSolutionVolumeTarget.value.trim() : ''
            contentId = this.hasStockSolutionSelectTarget ? this.stockSolutionSelectTarget.value : ''
            contentableType = 'StockSolution'

            if (!contentId) {
                this.showError("Please select a stock solution")
                return null
            }
        } else if (contentType === 'chemical') {
            volume = this.hasChemicalVolumeTarget ? this.chemicalVolumeTarget.value.trim() : ''
            contentId = this.hasChemicalSelectTarget ? this.chemicalSelectTarget.value : ''
            contentableType = 'Chemical'

            if (!contentId) {
                this.showError("Please select a chemical")
                return null
            }
        } else {
            this.showError("Please select a content type")
            return null
        }

        if (!volume) {
            this.showError("Please enter a volume/amount with unit (e.g., 50 μL, 10 mg)")
            return null
        }

        return {
            well_ids: this.wellIdsValue,
            contentable_type: contentableType,
            contentable_id: contentId,
            amount_with_unit: volume
        }
    }

    showError(message) {
        this.messagesTarget.innerHTML = `<div class="alert alert-danger">${message}</div>`

        // Auto-hide after 5 seconds
        setTimeout(() => {
            this.clearMessages()
        }, 5000)
    }

    showSuccess(message) {
        this.messagesTarget.innerHTML = `<div class="alert alert-success">${message}</div>`
    }

    clearMessages() {
        if (this.hasMessagesTarget) {
            this.messagesTarget.innerHTML = ""
        }
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