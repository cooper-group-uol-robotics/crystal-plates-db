import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "toleranceInput",
    "g6Content",
    "csdContent",
    "similarityButton"
  ]

  static values = {
    currentDatasetId: Number
  }

  connect() {
    console.log("G6 comparison controller connected!")

    // Load similarity counts for all datasets when the controller connects
    // Use a small delay to ensure DOM is fully loaded
    setTimeout(() => {
      this.loadSimilarityCounts()
    }, 2000)

    // Initialize card toggler if available
    this.initializeCardToggler()
  }

  initializeCardToggler() {
    if (window.scxrdCardToggler && typeof window.scxrdCardToggler.reinitialize === 'function') {
      setTimeout(() => {
        window.scxrdCardToggler.reinitialize()
      }, 500)
    }
  }

  loadG6Comparison(event) {
    console.log("G6 loadG6Comparison called!", event)

    // Prevent default action and stop event bubbling
    event.preventDefault()
    event.stopPropagation()

    const datasetId = parseInt(event.currentTarget.dataset.datasetId)
    console.log("Loading G6 comparison for dataset ID:", datasetId)

    // Debug: Check if targets are available
    console.log("G6Content target available:", this.hasG6ContentTarget)
    console.log("CSD Content target available:", this.hasCsdContentTarget)
    console.log("Tolerance input target available:", this.hasToleranceInputTarget)

    // Debug: Check if modal exists
    const modalElement = document.getElementById('wellG6ComparisonModal') || document.getElementById('g6ComparisonModal')
    console.log("Modal element found:", modalElement ? modalElement.id : "None")

    this.currentDatasetIdValue = datasetId
    const tolerance = this.hasToleranceInputTarget ? this.toleranceInputTarget.value : 10.0

    // Check if we have the required targets
    if (!this.hasG6ContentTarget) {
      console.error("G6Content target not found - cannot show G6 comparison")
      return
    }

    if (!this.hasCsdContentTarget) {
      console.error("CsdContent target not found - cannot show CSD search")
      return
    }

    // Show loading state for G6 comparison
    this.g6ContentTarget.innerHTML = `
      <div class="text-center py-4">
        <div class="spinner-border" role="status">
          <span class="visually-hidden">Loading...</span>
        </div>
        <p class="mt-2">Searching for similar unit cells...</p>
      </div>
    `

    // Show loading state for CSD search
    this.csdContentTarget.innerHTML = `
      <div class="text-center py-3">
        <div class="spinner-border spinner-border-sm" role="status">
          <span class="visually-hidden">Loading...</span>
        </div>
        <p class="mt-2 mb-0">Searching CSD...</p>
      </div>
    `

    // Manually show the modal (needed for nested modals)
    const g6ModalElement = document.getElementById('wellG6ComparisonModal') || document.getElementById('g6ComparisonModal')
    if (g6ModalElement) {
      console.log("Manually showing modal:", g6ModalElement.id)
      const modal = new bootstrap.Modal(g6ModalElement)
      modal.show()
    } else {
      console.error("Modal element not found!")
      return
    }

    // Fetch G6 comparison data
    fetch(`/scxrd_datasets/${datasetId}/g6_similar?tolerance=${tolerance}`)
      .then(response => response.json())
      .then(data => {
        this.displayG6Results(data)
      })
      .catch(error => {
        console.error('Error:', error)
        if (this.hasG6ContentTarget) {
          this.g6ContentTarget.innerHTML = `
              <div class="alert alert-danger">
                <i class="bi bi-exclamation-triangle me-2"></i>
                Error loading comparison data: ${error.message}
              </div>
            `
        }
      })

    // Automatically trigger CSD search
    this.searchCSD()
  }

  updateG6Comparison() {
    if (this.currentDatasetIdValue) {
      // Simulate clicking the button to reload the comparison
      const event = {
        currentTarget: {
          dataset: { datasetId: this.currentDatasetIdValue.toString() }
        }
      }
      this.loadG6Comparison(event)
    }
  }

  searchCSD() {
    if (!this.currentDatasetIdValue) return

    // Fetch CSD search data (max_hits fixed at 50)
    fetch(`/scxrd_datasets/${this.currentDatasetIdValue}/csd_search`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({
        max_hits: 50
      })
    })
      .then(response => response.json())
      .then(data => {
        this.displayCSDResults(data)
      })
      .catch(error => {
        console.error('Error:', error)
        this.csdContentTarget.innerHTML = `
        <div class="alert alert-danger">
          <i class="bi bi-exclamation-triangle me-2"></i>
          Error searching CSD: ${error.message}
        </div>
      `
      })
  }

  displayCSDResults(data) {
    if (!data.success) {
      this.csdContentTarget.innerHTML = `
        <div class="alert alert-warning">
          <i class="bi bi-info-circle me-2"></i>
          CSD Search Error: ${data.error || 'Unknown error occurred'}
        </div>
      `
      return
    }

    if (!data.results || data.results.length === 0) {
      this.csdContentTarget.innerHTML = `
        <div class="alert alert-info">
          <i class="bi bi-search me-2"></i>
          No similar structures found in the Cambridge Structural Database.
          <hr>
          <small class="text-muted">
            Try increasing the tolerance values or check if the unit cell parameters are correct.
          </small>
        </div>
      `
      return
    }

    // Sort results: complete matches first, then cell-only matches
    const sortedResults = data.results.sort((a, b) => {
      if (a.match_type === 'cell_and_formula' && b.match_type === 'cell_only') return -1
      if (a.match_type === 'cell_only' && b.match_type === 'cell_and_formula') return 1
      return 0
    })

    // Count matches
    const formulaMatches = sortedResults.filter(r => r.match_type === 'cell_and_formula').length
    const cellOnlyMatches = sortedResults.filter(r => r.match_type === 'cell_only').length

    let html = `
      <div class="alert alert-success">
        <i class="bi bi-check-circle me-2"></i>
        Found <strong>${sortedResults.length}</strong> similar structure(s) in the Cambridge Structural Database
        ${formulaMatches > 0 ? `
          <br>
          <small>
            <i class="bi bi-check-circle-fill text-success me-1"></i>${formulaMatches} complete matches (unit cell + formula)
            &nbsp;&nbsp;
            <i class="bi bi-check-circle text-muted me-1"></i>${cellOnlyMatches} unit cell only matches
          </small>
        ` : ''}
      </div>
    `

    // Show well formulas if available
    if (data.well_formulas && data.well_formulas.length > 0) {
      html += `
        <div class="alert alert-light border mb-3">
          <small class="text-muted">
            <strong>Well contains chemicals with formulas:</strong> 
            ${data.well_formulas.map(formula => `<code>${formula}</code>`).join(', ')}
          </small>
        </div>
      `
    }

    html += `      
      <div class="table-responsive">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>CSD Code</th>
              <th>Unit Cell</th>
              <th>Space Group</th>
              <th>Formula</th>
              <th>Match Type</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
    `

    sortedResults.forEach(structure => {
      const unitCellText = structure.cell_parameters && structure.cell_parameters.length >= 6 ?
        `a=${structure.cell_parameters[0].toFixed(3)}Å b=${structure.cell_parameters[1].toFixed(3)}Å c=${structure.cell_parameters[2].toFixed(3)}Å α=${structure.cell_parameters[3].toFixed(1)}° β=${structure.cell_parameters[4].toFixed(1)}° γ=${structure.cell_parameters[5].toFixed(1)}°` :
        'No unit cell data'

      const isCompleteMatch = structure.match_type === 'cell_and_formula'
      const rowClass = isCompleteMatch ? '' : 'text-muted'

      let matchBadge = '<span class="badge bg-secondary"><i class="bi bi-circle"></i> Cell Only</span>'
      if (isCompleteMatch) {
        let badgeText = '<i class="bi bi-check-circle-fill"></i> Complete Match'
        if (structure.matched_well_formula) {
          badgeText += ` (${structure.matched_well_formula})`
        }
        if (structure.similarity_score) {
          const scorePercent = Math.round(structure.similarity_score * 100)
          badgeText += ` ${scorePercent}%`
        }
        matchBadge = `<span class="badge bg-success">${badgeText}</span>`
      }

      html += `
        <tr class="${rowClass}">
          <td>
            <strong>${structure.identifier || 'Unknown'}</strong>
          </td>
          <td><small>${unitCellText}</small></td>
          <td><span class="badge bg-secondary">${structure.space_group || 'Unknown'}</span></td>
          <td><small><code>${structure.formula || 'Unknown'}</code></small></td>
          <td>${matchBadge}</td>
          <td>
            ${structure.identifier ? `
              <button type="button" class="btn btn-outline-info btn-sm" 
                      onclick="window.open('https://www.ccdc.cam.ac.uk/structures/Search?Ccdcid=${structure.identifier}', '_blank')">
                <i class="bi bi-box-arrow-up-right"></i> CCDC
              </button>
            ` : ''}
          </td>
        </tr>
      `
    })

    html += `
          </tbody>
        </table>
      </div>
    `

    this.csdContentTarget.innerHTML = html
  }

  displayG6Results(data) {
    if (!data.success) {
      this.g6ContentTarget.innerHTML = `
        <div class="alert alert-warning">
          <i class="bi bi-info-circle me-2"></i>
          ${data.error}
        </div>
      `
      return
    }

    if (data.count === 0) {
      this.g6ContentTarget.innerHTML = `
        <div class="alert alert-info">
          <i class="bi bi-search me-2"></i>
          No similar unit cells found within G6 distance of ${data.tolerance}.
          <hr>
          <small class="text-muted">
            <strong>Current dataset:</strong> ${data.current_dataset.experiment_name}<br>
            <strong>Unit cell:</strong> ${data.current_dataset.unit_cell ?
          `${data.current_dataset.unit_cell.bravais || 'P'} a=${data.current_dataset.unit_cell.a}Å b=${data.current_dataset.unit_cell.b}Å c=${data.current_dataset.unit_cell.c}Å α=${data.current_dataset.unit_cell.alpha}° β=${data.current_dataset.unit_cell.beta}° γ=${data.current_dataset.unit_cell.gamma}°` :
          'No unit cell'}
          </small>
        </div>
      `
      return
    }

    let html = `
      <div class="alert alert-success">
        <i class="bi bi-check-circle me-2"></i>
        Found <strong>${data.count}</strong> dataset(s) with similar unit cells (G6 distance ≤ ${data.tolerance})
      </div>
      
      <div class="mb-3">
        <small class="text-muted">
          <strong>Reference dataset:</strong> ${data.current_dataset.experiment_name}<br>
          <strong>Unit cell:</strong> ${data.current_dataset.unit_cell ?
        `${data.current_dataset.unit_cell.bravais || 'P'} a=${data.current_dataset.unit_cell.a}Å b=${data.current_dataset.unit_cell.b}Å c=${data.current_dataset.unit_cell.c}Å α=${data.current_dataset.unit_cell.alpha}° β=${data.current_dataset.unit_cell.beta}° γ=${data.current_dataset.unit_cell.gamma}°` :
        'No unit cell'}
        </small>
      </div>

      <div class="table-responsive">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Dataset</th>
              <th>Unit Cell</th>
              <th>G6 Distance</th>
              <th>Location</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
    `

    data.datasets.forEach(dataset => {
      const unitCellText = dataset.unit_cell ?
        `${dataset.unit_cell.bravais} a=${dataset.unit_cell.a}Å b=${dataset.unit_cell.b}Å c=${dataset.unit_cell.c}Å α=${dataset.unit_cell.alpha}° β=${dataset.unit_cell.beta}° γ=${dataset.unit_cell.gamma}°` :
        'No unit cell'

      const locationText = dataset.well ?
        `${dataset.well.plate_barcode}-${dataset.well.label}` :
        'Standalone'

      html += `
        <tr>
          <td>
            <strong>${dataset.experiment_name}</strong><br>
            <small class="text-muted">${dataset.measured_at}</small>
          </td>
          <td><small>${unitCellText}</small></td>
          <td><span class="badge bg-info">${dataset.g6_distance}</span></td>
          <td><small>${locationText}</small></td>
          <td>
            <a href="/scxrd_datasets/${dataset.id}" class="btn btn-outline-primary btn-sm" target="_blank">
              <i class="bi bi-eye"></i> View
            </a>
          </td>
        </tr>
      `
    })

    html += `
          </tbody>
        </table>
      </div>
    `

    this.g6ContentTarget.innerHTML = html
  }

  loadSimilarityCounts() {
    console.log("Loading similarity counts for buttons...")
    console.log("Found similarity button targets:", this.similarityButtonTargets.length)

    // Load similarity counts for all datasets with unit cells
    this.similarityButtonTargets.forEach((button, index) => {
      const datasetId = button.getAttribute('data-dataset-id')
      const textSpan = button.querySelector('.similarity-text')

      console.log(`Button ${index}: datasetId=${datasetId}, textSpan=${textSpan ? 'found' : 'not found'}`)

      if (!textSpan) return

      fetch(`/scxrd_datasets/${datasetId}/similarity_counts`)
        .then(response => response.json())
        .then(data => {
          if (data.success) {
            const g6Count = data.g6_count || 0
            const csdCount = data.csd_count || 0
            const csdFormulaMatches = data.csd_formula_matches || 0
            const totalCount = g6Count + csdCount

            if (totalCount > 0) {
              let buttonText = `${g6Count} local`
              if (csdCount > 0) {
                if (csdFormulaMatches > 0) {
                  buttonText += ` + ${csdCount} CSD (${csdFormulaMatches} formula match${csdFormulaMatches > 1 ? 'es' : ''})`
                } else {
                  buttonText += ` + ${csdCount} CSD`
                }
              }

              textSpan.textContent = buttonText
              button.classList.remove('btn-outline-secondary')

              // Use different color if we have formula matches
              if (csdFormulaMatches > 0) {
                button.classList.remove('btn-outline-info')
                button.classList.add('btn-outline-success', 'has-matches')
              } else {
                button.classList.remove('btn-outline-success')
                button.classList.add('btn-outline-info', 'has-matches')
              }
              button.disabled = false
            } else {
              textSpan.textContent = 'No similar unit cells'
              button.classList.remove('btn-outline-info', 'btn-outline-success')
              button.classList.add('btn-outline-secondary')
              button.disabled = true
            }
          } else {
            textSpan.textContent = 'No unit cell data'
            button.classList.remove('btn-outline-info', 'btn-outline-success')
            button.classList.add('btn-outline-secondary')
            button.disabled = true
          }
        })
        .catch(error => {
          console.error('Error loading similarity counts:', error)
          textSpan.textContent = 'Error loading'
          button.classList.remove('btn-outline-info', 'btn-outline-success')
          button.classList.add('btn-outline-secondary')
          button.disabled = true
        })
    })
  }
}