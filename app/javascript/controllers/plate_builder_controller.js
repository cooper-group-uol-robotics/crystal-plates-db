import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "plateBarcode", "plateGrid", "plateGridPlaceholder", "mainGrid",
    "chemicalPanel", "selectedWellLabel", "chemicalBarcode", "chemicalFeedback",
    "massInputSection", "chemicalMass", "chemicalInfo", "chemicalName", "chemicalCas",
    "wellsFilledCount", "currentPlateBarcode", "savePlateBtn", "screenFlash", "plateStatus"
  ]

  static values = {
    checkChemicalCasUrl: String,
    createFromBuilderUrl: String,
    chemicalSearchUrl: String,
    loadForBuilderUrl: String,
    saveWellUrl: String,
    csrfToken: String
  }

  connect() {
    console.log('PlateBuilder controller connected')
    this.currentPlate = null
    this.existingPlateId = null
    this.isExistingPlate = false
    this.selectedWell = null
    this.wellData = {}

    // Focus plate barcode input when controller connects
    if (this.hasPlateBarcodeTarget) {
      this.plateBarcodeTarget.focus()
      console.log('Plate barcode input focused')
    } else {
      console.log('Plate barcode target not found')
    }
  }

  disconnect() {
    // Cleanup when navigating away
    this.currentPlate = null
    this.existingPlateId = null
    this.isExistingPlate = false
    this.selectedWell = null
    this.wellData = {}
  }

  // Handle plate barcode input
  plateBarcodeKeypress(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      const barcode = this.normalizeBarcode(event.target.value.trim())
      if (barcode) {
        this.handlePlateBarcodeInput(barcode)
      }
    }
  }

  // Handle chemical barcode input
  chemicalBarcodeKeypress(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      const barcode = this.normalizeBarcode(event.target.value.trim())
      if (barcode) {
        this.handleChemicalBarcodeInput(barcode)
      }
    }
  }

  // Handle mass input from balance
  chemicalMassKeypress(event) {
    if (event.key === 'Enter') {
      event.preventDefault()
      this.handleMassInput()
    }
  }

  // Handle well selection
  selectWell(event) {
    const wellId = event.target.closest('[data-well-id]').dataset.wellId
    if (wellId) {
      this.setSelectedWell(wellId)
    }
  }

  // Clear selected well
  async clearWell() {
    if (!this.selectedWell) return

    try {
      // Save empty state to database (clears the well contents)
      await this.saveWellToDatabase(this.selectedWell, {})

      // Update local state
      delete this.wellData[this.selectedWell]

      // Update visual state
      this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
        el.classList.remove('filled', 'valid', 'error')
      })

      this.updateWellsFilledCount()
      this.cancelWellSelection()
      this.showToast(`Well ${this.selectedWell} cleared`, 'info')
    } catch (error) {
      console.error('Error clearing well:', error)
      this.showToast(`Error clearing well ${this.selectedWell}: ${error.message}`, 'danger')
    }
  }

  // Cancel well selection
  cancelWell() {
    this.cancelWellSelection()
  }

  // Navigate to plate view (wells are already saved individually)
  async savePlate() {
    if (!this.currentPlate) {
      this.showToast('No plate barcode entered', 'warning')
      return
    }

    // Since wells are saved individually, just navigate to the plate
    this.showToast('Navigating to plate view...', 'info')

    // Find or create the plate to get its ID for navigation
    try {
      let plateId = this.existingPlateId

      if (!plateId) {
        // Create plate if it doesn't exist yet
        const response = await fetch(this.createFromBuilderUrlValue, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': this.csrfTokenValue
          },
          body: JSON.stringify({
            barcode: this.currentPlate,
            wells: {}, // Empty since wells are saved individually
            existing_plate_id: this.existingPlateId,
            is_existing_plate: this.isExistingPlate
          })
        })

        const data = await response.json()
        if (data.success) {
          plateId = data.plate_id
        } else {
          throw new Error(data.error)
        }
      }

      // Navigate to plate view
      if (plateId) {
        setTimeout(() => {
          Turbo.visit(`/plates/${plateId}`)
        }, 500)
      } else {
        this.showToast('Error: Could not determine plate ID', 'danger')
      }
    } catch (error) {
      console.error('Error navigating to plate:', error)
      this.showToast('Error: ' + error.message, 'danger')
    }
  }

  // Private methods
  normalizeBarcode(barcode) {
    if (!barcode) return barcode

    // Remove leading zeros from numeric barcodes
    // Keep at least one digit if the barcode is all zeros
    const normalized = barcode.replace(/^0+/, '') || '0'

    console.log(`Normalized barcode: "${barcode}" -> "${normalized}"`)
    return normalized
  }

  async handlePlateBarcodeInput(barcode) {
    console.log('Handling plate barcode input:', barcode)

    try {
      // First, try to load an existing plate with this barcode
      const loadUrl = this.loadForBuilderUrlValue.replace(':barcode', encodeURIComponent(barcode))
      const response = await fetch(loadUrl)
      const data = await response.json()

      this.currentPlate = barcode
      this.currentPlateBarcodeTarget.textContent = barcode

      if (data.found) {
        // Existing plate found - load its data
        this.isExistingPlate = true
        this.existingPlateId = data.plate.id
        this.wellData = data.wells || {}

        this.showToast(`Existing plate loaded: ${data.plate.name || barcode}`, 'info')

        // Update wells visual state
        this.loadExistingWellsIntoGrid()

        // Show status indicator for existing plate
        this.plateStatusTarget.textContent = `Status: Existing plate (editing)`
        this.plateStatusTarget.className = 'text-info'
        this.plateStatusTarget.style.display = 'block'

        // Update save button text
        this.savePlateBtnTarget.innerHTML = '<i class="bi bi-pencil-square"></i> Update Plate'
      } else {
        // New plate
        this.isExistingPlate = false
        this.existingPlateId = null
        this.wellData = {}

        this.showToast('New plate - ready for chemical input', 'success')

        // Show status indicator for new plate
        this.plateStatusTarget.textContent = `Status: New plate`
        this.plateStatusTarget.className = 'text-success'
        this.plateStatusTarget.style.display = 'block'

        // Ensure save button text is correct
        this.savePlateBtnTarget.innerHTML = '<i class="bi bi-check-lg"></i> Save Plate'
      }

      // Enable plate grid in both cases
      console.log('Enabling plate grid...')
      this.enablePlateGrid()
      this.plateGridTarget.style.display = 'block'
      this.plateGridPlaceholderTarget.style.display = 'none'
      this.updateWellsFilledCount()

    } catch (error) {
      console.error('Error checking for existing plate:', error)
      // Fall back to new plate behavior
      this.currentPlate = barcode
      this.currentPlateBarcodeTarget.textContent = barcode
      this.isExistingPlate = false
      this.existingPlateId = null
      this.wellData = {}

      this.enablePlateGrid()
      this.plateGridTarget.style.display = 'block'
      this.plateGridPlaceholderTarget.style.display = 'none'

      // Show status as new plate (fallback)
      this.plateStatusTarget.textContent = `Status: New plate`
      this.plateStatusTarget.className = 'text-success'
      this.plateStatusTarget.style.display = 'block'
      this.savePlateBtnTarget.innerHTML = '<i class="bi bi-check-lg"></i> Save Plate'

      this.showToast('Plate barcode scanned successfully', 'success')
    }
  }

  loadExistingWellsIntoGrid() {
    // Mark wells that have existing content as filled
    Object.keys(this.wellData).forEach(wellId => {
      this.element.querySelectorAll(`[data-well-id="${wellId}"]`).forEach(el => {
        el.classList.add('filled')
        el.classList.remove('valid', 'error', 'selected')
      })
    })
  }

  enablePlateGrid() {
    console.log('enablePlateGrid called')

    // Remove disabled state from main grid
    this.mainGridTarget.classList.remove('plate-disabled')

    console.log('Plate grid enabled')
  }

  setSelectedWell(wellId) {
    // Deselect previous well
    if (this.selectedWell) {
      this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
        el.classList.remove('selected')
      })
    }

    // Select new well
    this.selectedWell = wellId
    this.element.querySelectorAll(`[data-well-id="${wellId}"]`).forEach(el => {
      el.classList.add('selected')
    })

    // Update UI
    this.selectedWellLabelTarget.textContent = wellId
    this.chemicalPanelTarget.style.display = 'block'

    // Clear inputs
    this.chemicalBarcodeTarget.value = ''
    this.chemicalMassTarget.value = ''
    this.massInputSectionTarget.style.display = 'none'
    this.chemicalInfoTarget.style.display = 'none'

    // Focus chemical barcode input
    this.chemicalBarcodeTarget.focus()

    // Restore well data if exists
    if (this.wellData[wellId]) {
      const wellInfo = this.wellData[wellId]
      this.chemicalBarcodeTarget.value = wellInfo.chemical_barcode || ''
      if (wellInfo.chemical_id) {
        this.showChemicalInfo(wellInfo.chemical_name, wellInfo.chemical_cas)
        if (wellInfo.mass) {
          // Convert mg back to grams for balance display
          this.chemicalMassTarget.value = (wellInfo.mass / 1000.0).toFixed(4)
          this.massInputSectionTarget.style.display = 'block'
        }
      }
    }
  }

  async handleChemicalBarcodeInput(barcode) {
    if (!barcode || !this.selectedWell) return

    try {
      // Find chemical by barcode using exact match only (no substring matching)
      const searchUrl = new URL(this.chemicalSearchUrlValue, window.location.origin)
      searchUrl.searchParams.set('q', barcode)
      searchUrl.searchParams.set('exact_only', 'true')

      const response = await fetch(searchUrl)

      // Check if response is ok and has valid content type
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const contentType = response.headers.get('content-type')
      if (!contentType || !contentType.includes('application/json')) {
        throw new Error('Invalid response: expected JSON')
      }

      const data = await response.json()

      if (data && data.length > 0) {
        const chemical = data[0]

        // First check if this chemical is already used in the current plate
        const conflictingWell = Object.keys(this.wellData).find(wellId =>
          this.wellData[wellId].chemical_cas === chemical.cas
        )

        if (conflictingWell) {
          // Flash red and clear input - chemical already used in current plate
          this.flashScreen('red')
          this.chemicalBarcodeTarget.value = ''
          this.setFeedbackMessage(`This chemical (CAS: ${chemical.cas}) is already used in well ${conflictingWell} on this plate`, 'form-text text-danger')

          // Mark well as error
          this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
            el.classList.add('error')
          })

          // Keep focus in the chemical barcode input
          this.chemicalBarcodeTarget.focus()
          return
        }

        // Then check CAS usage in other plates in the database
        const casUrl = new URL(this.checkChemicalCasUrlValue, window.location.origin)
        casUrl.searchParams.set('chemical_id', chemical.id)

        const casResponse = await fetch(casUrl)
        const casData = await casResponse.json()

        if (casData.cas_used) {
          // Flash red and clear input - chemical used in other plates
          this.flashScreen('red')
          this.chemicalBarcodeTarget.value = ''

          // Show detailed conflict information
          let conflictMessage = `This chemical (CAS: ${chemical.cas}) has already been used:`
          if (casData.conflicts && casData.conflicts.length > 0) {
            const conflicts = casData.conflicts.slice(0, 3) // Show max 3 conflicts to avoid UI overflow
            const conflictDetails = conflicts.map(conflict =>
              `\n• Plate ${conflict.plate_barcode}${conflict.plate_name ? ` (${conflict.plate_name})` : ''}, Well ${conflict.well_position}: ${conflict.chemical_name}${conflict.chemical_barcode ? ` [${conflict.chemical_barcode}]` : ''}`
            ).join('')
            conflictMessage += conflictDetails

            if (casData.conflicts.length > 3) {
              conflictMessage += `\n• ...and ${casData.conflicts.length - 3} more`
            }
          } else {
            conflictMessage += ' in another plate'
          }

          this.setFeedbackMessage(conflictMessage, 'form-text text-danger', true)

          // Mark well as error
          this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
            el.classList.add('error')
          })

          // Keep focus in the chemical barcode input
          this.chemicalBarcodeTarget.focus()
        } else {
          // Flash green and proceed
          this.flashScreen('green')
          this.setFeedbackMessage('Chemical approved - ready for weighing', 'form-text text-success')

          // Show chemical info
          this.showChemicalInfo(chemical.name, chemical.cas)
          this.massInputSectionTarget.style.display = 'block'

          // Store chemical info
          if (!this.wellData[this.selectedWell]) {
            this.wellData[this.selectedWell] = {}
          }
          this.wellData[this.selectedWell].chemical_id = chemical.id
          this.wellData[this.selectedWell].chemical_name = chemical.name
          this.wellData[this.selectedWell].chemical_cas = chemical.cas
          this.wellData[this.selectedWell].chemical_barcode = chemical.barcode

          // Mark well as valid
          this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
            el.classList.remove('error')
            el.classList.add('valid')
          })

          this.chemicalMassTarget.focus()
        }
      } else {
        // Flash red for chemical not found
        this.flashScreen('red')
        this.setFeedbackMessage(`Chemical not found for barcode: ${barcode}`, 'form-text text-danger')
        // Keep focus in the chemical barcode input for retry
        this.chemicalBarcodeTarget.focus()
      }
    } catch (error) {
      console.error('Error checking chemical:', error)

      // Flash red for any error (including chemical not found)
      this.flashScreen('red')

      // Check if it's a JSON parsing error or network error - likely means chemical not found
      if (error.message.includes('JSON') || error.message.includes('Invalid response')) {
        this.setFeedbackMessage(`Chemical not found for barcode: ${barcode}`, 'form-text text-danger')
        this.chemicalBarcodeTarget.focus()
      } else {
        // Other errors
        this.setFeedbackMessage(`Error checking chemical: ${error.message}`, 'form-text text-danger')
        this.showToast('Error checking chemical: ' + error.message, 'danger')
      }
    }
  }

  async handleMassInput() {
    const massField = this.chemicalMassTarget
    let rawMass = massField.value.trim()

    if (!rawMass || !this.selectedWell) return

    // Convert from balance units (g) to mg by multiplying by 1000
    const massInMg = parseFloat(rawMass) * 1000
    massField.value = massInMg.toFixed(4)

    // Store mass data locally first (in mg for consistency)
    if (this.wellData[this.selectedWell]) {
      this.wellData[this.selectedWell].mass = massInMg

      // Save to database immediately
      try {
        await this.saveWellToDatabase(this.selectedWell, this.wellData[this.selectedWell])

        // Mark well as filled only after successful save
        this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
          el.classList.add('filled')
          el.classList.remove('valid', 'error')
        })

        // Clear feedback text after successful weighing
        this.setFeedbackMessage('', 'form-text')

        this.updateWellsFilledCount()
        this.showToast(`Well ${this.selectedWell} saved with ${massInMg.toFixed(2)} mg`, 'success')

        // Auto-advance to next available well
        this.advanceToNextWell()
      } catch (error) {
        console.error('Error saving well:', error)
        this.showToast(`Error saving well ${this.selectedWell}: ${error.message}`, 'danger')
        // Don't advance to next well if save failed
      }
    }
  }

  async saveWellToDatabase(wellPosition, wellData) {
    const response = await fetch(this.saveWellUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfTokenValue
      },
      body: JSON.stringify({
        barcode: this.currentPlate,
        well_position: wellPosition,
        well_data: wellData
      })
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    const data = await response.json()

    if (!data.success) {
      throw new Error(data.error || 'Unknown error occurred')
    }

    return data
  }

  advanceToNextWell() {
    if (!this.currentPlate) return

    // Generate all well IDs in order (A1, A2, ..., A12, B1, B2, ..., H12)
    const allWells = []
    for (let row = 0; row < 8; row++) {
      const rowLetter = String.fromCharCode(65 + row) // A, B, C, ..., H
      for (let col = 1; col <= 12; col++) {
        allWells.push(`${rowLetter}${col}`)
      }
    }

    // Find current well index
    const currentIndex = allWells.indexOf(this.selectedWell)
    if (currentIndex === -1) {
      // If current well not found, cancel selection
      this.cancelWellSelection()
      return
    }

    // Find next available (unfilled) well
    for (let i = currentIndex + 1; i < allWells.length; i++) {
      const wellId = allWells[i]
      if (!this.wellData[wellId]) {
        // Found an empty well - select it
        this.setSelectedWell(wellId)
        return
      }
    }

    // If no wells found after current position, check from beginning
    for (let i = 0; i < currentIndex; i++) {
      const wellId = allWells[i]
      if (!this.wellData[wellId]) {
        // Found an empty well - select it
        this.setSelectedWell(wellId)
        return
      }
    }

    // All wells are filled - cancel selection and show completion message
    this.cancelWellSelection()
    this.showToast('All wells are filled! Ready to save plate.', 'info')
  }

  showChemicalInfo(name, cas) {
    this.chemicalNameTarget.textContent = name
    this.chemicalCasTarget.textContent = cas || 'Not specified'
    this.chemicalInfoTarget.style.display = 'block'
  }

  flashScreen(color) {
    const flash = this.screenFlashTarget
    flash.className = `screen-flash ${color}`
    flash.style.display = 'block'

    setTimeout(() => flash.style.opacity = '0.8', 10)
    setTimeout(() => {
      flash.style.display = 'none'
      flash.style.opacity = '0'
    }, 300)
  }

  cancelWellSelection() {
    if (this.selectedWell) {
      this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
        el.classList.remove('selected')
      })
    }

    this.selectedWell = null
    this.chemicalPanelTarget.style.display = 'none'
    this.plateBarcodeTarget.focus()
  }

  updateWellsFilledCount() {
    const filledCount = Object.keys(this.wellData).length
    this.wellsFilledCountTarget.textContent = filledCount
    // Enable save button as soon as a plate is loaded (wells are saved individually)
    this.savePlateBtnTarget.disabled = !this.currentPlate
  }

  showToast(message, type = 'info') {
    // Create toast element dynamically to work with Turbo
    const toastHtml = `
      <div class="toast" role="alert" aria-live="assertive" aria-atomic="true">
        <div class="toast-header">
          <i class="${this.getToastIcon(type)} me-2"></i>
          <strong class="me-auto">Plate Builder</strong>
          <button type="button" class="btn-close" data-bs-dismiss="toast"></button>
        </div>
        <div class="toast-body">${message}</div>
      </div>
    `

    // Find or create toast container
    let container = document.querySelector('.toast-container')
    if (!container) {
      container = document.createElement('div')
      container.className = 'toast-container position-fixed bottom-0 end-0 p-3'
      document.body.appendChild(container)
    }

    const toastElement = document.createElement('div')
    toastElement.innerHTML = toastHtml
    const toast = toastElement.firstElementChild

    container.appendChild(toast)

    const bsToast = new window.bootstrap.Toast(toast)
    bsToast.show()

    // Clean up after toast hides
    toast.addEventListener('hidden.bs.toast', () => {
      toast.remove()
    })
  }

  setFeedbackMessage(message, className = 'form-text', allowMultiLine = false) {
    this.chemicalFeedbackTarget.textContent = message
    this.chemicalFeedbackTarget.className = className
    this.chemicalFeedbackTarget.style.whiteSpace = allowMultiLine ? 'pre-line' : 'normal'
  }

  getToastIcon(type) {
    const iconMap = {
      success: 'bi-check-circle-fill text-success',
      danger: 'bi-exclamation-triangle-fill text-danger',
      warning: 'bi-exclamation-triangle-fill text-warning',
      info: 'bi-info-circle-fill text-info'
    }
    return iconMap[type] || iconMap.info
  }
}