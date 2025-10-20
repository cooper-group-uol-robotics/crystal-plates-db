import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "plateBarcode", "plateGrid", "plateGridPlaceholder", "mainGrid",
    "chemicalPanel", "selectedWellLabel", "chemicalBarcode", "chemicalFeedback",
    "massInputSection", "chemicalMass", "chemicalInfo", "chemicalName", "chemicalCas",
    "wellsFilledCount", "currentPlateBarcode", "savePlateBtn", "screenFlash"
  ]

  static values = {
    checkChemicalCasUrl: String,
    createFromBuilderUrl: String,
    chemicalSearchUrl: String,
    csrfToken: String
  }

  connect() {
    console.log('PlateBuilder controller connected')
    this.currentPlate = null
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
  clearWell() {
    if (!this.selectedWell) return

    delete this.wellData[this.selectedWell]

    // Update visual state
    this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
      el.classList.remove('filled', 'valid', 'error')
    })

    this.updateWellsFilledCount()
    this.cancelWellSelection()
  }

  // Cancel well selection
  cancelWell() {
    this.cancelWellSelection()
  }

  // Save plate
  async savePlate() {
    if (!this.currentPlate || Object.keys(this.wellData).length === 0) {
      this.showToast('No plate data to save', 'warning')
      return
    }

    try {
      const response = await fetch(this.createFromBuilderUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfTokenValue
        },
        body: JSON.stringify({
          barcode: this.currentPlate,
          wells: this.wellData
        })
      })

      const data = await response.json()

      if (data.success) {
        this.showToast('Plate saved successfully!', 'success')

        // Use Turbo.visit for navigation
        setTimeout(() => {
          Turbo.visit(data.redirect_url)
        }, 1500)
      } else {
        this.showToast('Error saving plate: ' + data.error, 'danger')
      }
    } catch (error) {
      console.error('Error saving plate:', error)
      this.showToast('Error saving plate: ' + error.message, 'danger')
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

  handlePlateBarcodeInput(barcode) {
    console.log('Handling plate barcode input:', barcode)
    this.currentPlate = barcode
    this.currentPlateBarcodeTarget.textContent = barcode

    // Enable plate grid
    console.log('Enabling plate grid...')
    this.enablePlateGrid()
    this.plateGridTarget.style.display = 'block'
    this.plateGridPlaceholderTarget.style.display = 'none'

    this.showToast('Plate barcode scanned successfully', 'success')
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
          this.chemicalMassTarget.value = (wellInfo.mass / 10).toFixed(4)
          this.massInputSectionTarget.style.display = 'block'
        }
      }
    }
  }

  async handleChemicalBarcodeInput(barcode) {
    if (!barcode || !this.selectedWell) return

    try {
      // Find chemical by barcode using the correct query parameter
      const searchUrl = new URL(this.chemicalSearchUrlValue, window.location.origin)
      searchUrl.searchParams.set('q', barcode)

      const response = await fetch(searchUrl)
      const data = await response.json()

      if (data && data.length > 0) {
        const chemical = data[0]

        // First check if this chemical is already used in the current plate
        const currentPlateHasChemical = Object.values(this.wellData).some(wellInfo =>
          wellInfo.chemical_cas === chemical.cas
        )

        if (currentPlateHasChemical) {
          // Flash red and clear input - chemical already used in current plate
          this.flashScreen('red')
          this.chemicalBarcodeTarget.value = ''
          this.chemicalFeedbackTarget.textContent = `This chemical (CAS: ${chemical.cas}) is already used in another well on this plate`
          this.chemicalFeedbackTarget.className = 'form-text text-danger'

          // Mark well as error
          this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
            el.classList.add('error')
          })
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
          this.chemicalFeedbackTarget.textContent = `This chemical (CAS: ${chemical.cas}) has already been used in another plate`
          this.chemicalFeedbackTarget.className = 'form-text text-danger'

          // Mark well as error
          this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
            el.classList.add('error')
          })
        } else {
          // Flash green and proceed
          this.flashScreen('green')
          this.chemicalFeedbackTarget.textContent = 'Chemical approved - ready for weighing'
          this.chemicalFeedbackTarget.className = 'form-text text-success'

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
        this.chemicalFeedbackTarget.textContent = `Chemical not found for barcode: ${barcode}`
        this.chemicalFeedbackTarget.className = 'form-text text-warning'
      }
    } catch (error) {
      console.error('Error checking chemical:', error)
      this.showToast('Error checking chemical: ' + error.message, 'danger')
    }
  }

  handleMassInput() {
    const massField = this.chemicalMassTarget
    let rawMass = massField.value.trim()

    if (!rawMass || !this.selectedWell) return

    // Convert from balance units (100s of μg) to mg by dividing by 10
    const massInMg = parseFloat(rawMass) / 10
    massField.value = massInMg.toFixed(4)

    // Store mass data
    if (this.wellData[this.selectedWell]) {
      this.wellData[this.selectedWell].mass = parseFloat(rawMass)

      // Mark well as filled
      this.element.querySelectorAll(`[data-well-id="${this.selectedWell}"]`).forEach(el => {
        el.classList.add('filled')
        el.classList.remove('valid', 'error')
      })

      // Clear feedback text after successful weighing
      this.chemicalFeedbackTarget.textContent = ''
      this.chemicalFeedbackTarget.className = 'form-text'

      this.updateWellsFilledCount()
      this.showToast(`Well ${this.selectedWell} filled with ${massInMg.toFixed(2)} mg`, 'success')

      // Auto-advance to next available well
      this.advanceToNextWell()
    }
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
    this.savePlateBtnTarget.disabled = filledCount === 0
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