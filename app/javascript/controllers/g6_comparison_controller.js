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
        // Load similarity counts for all datasets when the controller connects
        this.loadSimilarityCounts()

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
        const datasetId = parseInt(event.currentTarget.dataset.datasetId)
        this.currentDatasetIdValue = datasetId
        const tolerance = this.toleranceInputTarget.value

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

        // Fetch G6 comparison data
        fetch(`/scxrd_datasets/${datasetId}/g6_similar?tolerance=${tolerance}`)
            .then(response => response.json())
            .then(data => {
                this.displayG6Results(data)
            })
            .catch(error => {
                console.error('Error:', error)
                this.g6ContentTarget.innerHTML = `
          <div class="alert alert-danger">
            <i class="bi bi-exclamation-triangle me-2"></i>
            Error loading comparison data: ${error.message}
          </div>
        `
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

        let html = `
      <div class="alert alert-success">
        <i class="bi bi-check-circle me-2"></i>
        Found <strong>${data.results.length}</strong> similar structure(s) in the Cambridge Structural Database
      </div>
      
      <div class="table-responsive">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>CSD Code</th>
              <th>Unit Cell</th>
              <th>Space Group</th>
              <th>Formula</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
    `

        data.results.forEach(structure => {
            const unitCellText = structure.cell_parameters && structure.cell_parameters.length >= 6 ?
                `a=${structure.cell_parameters[0].toFixed(3)}Å b=${structure.cell_parameters[1].toFixed(3)}Å c=${structure.cell_parameters[2].toFixed(3)}Å α=${structure.cell_parameters[3].toFixed(1)}° β=${structure.cell_parameters[4].toFixed(1)}° γ=${structure.cell_parameters[5].toFixed(1)}°` :
                'No unit cell data'

            html += `
        <tr>
          <td>
            <strong>${structure.identifier || 'Unknown'}</strong>
          </td>
          <td><small>${unitCellText}</small></td>
          <td><span class="badge bg-secondary">${structure.space_group || 'Unknown'}</span></td>
          <td><small>${structure.formula || 'Unknown'}</small></td>
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
        // Load similarity counts for all datasets with unit cells
        this.similarityButtonTargets.forEach(button => {
            const datasetId = button.getAttribute('data-dataset-id')
            const textSpan = button.querySelector('.similarity-text')

            if (!textSpan) return

            fetch(`/scxrd_datasets/${datasetId}/similarity_counts`)
                .then(response => response.json())
                .then(data => {
                    if (data.success) {
                        const g6Count = data.g6_count || 0
                        const csdCount = data.csd_count || 0
                        const totalCount = g6Count + csdCount

                        if (totalCount > 0) {
                            textSpan.textContent = `${g6Count} local + ${csdCount} CSD matches`
                            button.classList.remove('btn-outline-secondary')
                            button.classList.add('btn-outline-info', 'has-matches')
                            button.disabled = false
                        } else {
                            textSpan.textContent = 'No similar unit cells'
                            button.classList.remove('btn-outline-info')
                            button.classList.add('btn-outline-secondary')
                            button.disabled = true
                        }
                    } else {
                        textSpan.textContent = 'No unit cell data'
                        button.classList.remove('btn-outline-info')
                        button.classList.add('btn-outline-secondary')
                        button.disabled = true
                    }
                })
                .catch(error => {
                    console.error('Error loading similarity counts:', error)
                    textSpan.textContent = 'Error loading'
                    button.classList.remove('btn-outline-info')
                    button.classList.add('btn-outline-secondary')
                    button.disabled = true
                })
        })
    }
}