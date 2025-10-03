import { Controller } from "@hotwired/stimulus"
import { Chart, registerables } from 'chart.js'
import zoomPlugin from 'chartjs-plugin-zoom'

// Register Chart.js components
Chart.register(...registerables, zoomPlugin)

export default class extends Controller {
  static targets = [
    "compareButton", 
    "selectedCount", 
    "patternsList", 
    "overlayChart", 
    "overlayLoading",
    "patternCard"
  ]
  
  static values = {
    selectedPatterns: Array
  }
  
  // Color palette for different patterns
  static PATTERN_COLORS = [
    'rgba(54, 162, 235, 1)',   // Blue
    'rgba(255, 99, 132, 1)',   // Red
    'rgba(75, 192, 192, 1)',   // Teal
    'rgba(255, 206, 86, 1)',   // Yellow
    'rgba(153, 102, 255, 1)',  // Purple
    'rgba(255, 159, 64, 1)',   // Orange
    'rgba(199, 199, 199, 1)',  // Grey
    'rgba(83, 102, 146, 1)',   // Dark Blue
    'rgba(255, 99, 255, 1)',   // Magenta
    'rgba(99, 255, 132, 1)'    // Green
  ]
  
  connect() {
    this.selectedPatterns = new Set()
    this.overlayChart = null
    this.updateUI()
  }
  
  disconnect() {
    this.cleanup()
  }
  
  cleanup() {
    if (this.overlayChart) {
      this.overlayChart.destroy()
      this.overlayChart = null
    }
    this.selectedPatterns.clear()
    this.clearSelections()
    this.updateUI()
  }
  
  selectPattern(event) {
    // Don't interfere with action button clicks
    if (event.target.closest('.btn-group') || event.target.closest('.btn')) {
      return
    }
    
    const card = event.currentTarget
    const patternId = parseInt(card.dataset.patternId)
    const hasData = card.dataset.hasData === 'true'
    
    // Skip if this pattern has no data
    if (!hasData) {
      this.showNoDataTooltip(card)
      return
    }
    
    const checkbox = document.getElementById(`pattern-${patternId}-checkbox`)
    
    if (this.selectedPatterns.has(patternId)) {
      // Deselect
      this.selectedPatterns.delete(patternId)
      card.classList.remove('selected')
      if (checkbox) checkbox.checked = false
    } else {
      // Select
      this.selectedPatterns.add(patternId)
      card.classList.add('selected')
      if (checkbox) checkbox.checked = true
    }
    
    this.updateUI()
  }
  
  showNoDataTooltip(card) {
    const tooltip = document.createElement('div')
    tooltip.className = 'position-absolute bg-dark text-white p-2 rounded'
    tooltip.style.cssText = 'top: 50%; left: 50%; transform: translate(-50%, -50%); z-index: 1000; font-size: 12px;'
    tooltip.textContent = 'No data file available'
    card.appendChild(tooltip)
    
    setTimeout(() => {
      if (tooltip.parentNode) {
        tooltip.parentNode.removeChild(tooltip)
      }
    }, 2000)
  }
  
  clearSelections() {
    this.patternCardTargets.forEach(card => {
      card.classList.remove('selected')
      const patternId = card.dataset.patternId
      const checkbox = document.getElementById(`pattern-${patternId}-checkbox`)
      if (checkbox) checkbox.checked = false
    })
  }
  
  toggleLegend() {
    if (this.overlayChart) {
      this.overlayChart.options.plugins.legend.display = !this.overlayChart.options.plugins.legend.display
      this.overlayChart.update()
    }
  }
  
  resetZoom() {
    if (this.overlayChart) {
      this.overlayChart.resetZoom()
    }
  }
  
  modalShown() {
    this.renderOverlayChart()
  }
  
  updateUI() {
    const count = this.selectedPatterns.size
    
    // Update compare button
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = count
    }
    
    if (this.hasCompareButtonTarget) {
      this.compareButtonTarget.style.display = count > 0 ? 'block' : 'none'
    }
    
    // Update patterns list
    if (this.hasPatternsListTarget) {
      if (count === 0) {
        this.patternsListTarget.textContent = 'None selected'
        this.patternsListTarget.className = 'text-muted'
      } else {
        const patternNames = Array.from(this.selectedPatterns).map(id => {
          const checkbox = document.getElementById(`pattern-${id}-checkbox`)
          return checkbox ? checkbox.dataset.patternTitle : `Pattern #${id}`
        })
        this.patternsListTarget.textContent = patternNames.join(', ')
        this.patternsListTarget.className = 'text-dark fw-bold'
      }
    }
  }
  
  async loadPxrdData(patternId) {
    const response = await fetch(`/api/v1/pxrd_patterns/${patternId}/data`)
    if (!response.ok) {
      throw new Error(`Failed to load pattern ${patternId}: ${response.statusText}`)
    }
    return response.json()
  }
  
  async renderOverlayChart() {
    if (!this.hasOverlayChartTarget) return
    
    const canvas = this.overlayChartTarget
    const loading = this.hasOverlayLoadingTarget ? this.overlayLoadingTarget : null
    
    if (this.selectedPatterns.size === 0) {
      if (this.overlayChart) {
        this.overlayChart.destroy()
        this.overlayChart = null
      }
      canvas.getContext('2d').clearRect(0, 0, canvas.width, canvas.height)
      return
    }
    
    if (loading) loading.style.display = 'block'
    
    try {
      // Load data for all selected patterns
      const patternPromises = Array.from(this.selectedPatterns).map(async (patternId, index) => {
        const data = await this.loadPxrdData(patternId)
        const checkbox = document.getElementById(`pattern-${patternId}-checkbox`)
        const title = checkbox ? checkbox.dataset.patternTitle : `Pattern #${patternId}`
        
        // Use filename from metadata if available, otherwise fallback to title
        const filename = data.data.metadata?.filename || title
        
        return {
          id: patternId,
          title: filename,
          data: data.data,
          color: this.constructor.PATTERN_COLORS[index % this.constructor.PATTERN_COLORS.length]
        }
      })
      
      const patterns = await Promise.all(patternPromises)
      
      // Destroy existing chart
      if (this.overlayChart) {
        this.overlayChart.destroy()
      }
      
      // Prepare datasets for Chart.js
      const datasets = patterns.map(pattern => ({
        label: pattern.title,
        data: pattern.data.two_theta.map((x, i) => ({ x, y: pattern.data.intensities[i] })),
        borderColor: pattern.color,
        backgroundColor: pattern.color.replace('1)', '0.1)'),
        showLine: true,
        pointRadius: 0,
        borderWidth: 2,
        fill: false,
        tension: 0.1
      }))
      
      // Create overlay chart
      this.overlayChart = new Chart(canvas.getContext('2d'), {
        type: 'scatter',
        data: { datasets },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: true,
              position: 'top',
              labels: {
                usePointStyle: true,
                pointStyle: 'line'
              }
            },
            title: {
              display: true,
              text: `Overlaid PXRD Patterns (${patterns.length} patterns)`,
              font: { size: 16 }
            },
            zoom: {
              pan: {
                enabled: true,
                mode: 'xy',
                modifierKey: 'ctrl'
              },
              zoom: {
                drag: { enabled: true },
                pinch: { enabled: true },
                mode: 'xy'
              }
            }
          },
          scales: {
            x: {
              type: 'linear',
              title: {
                display: true,
                text: '2θ (degrees)',
                font: { size: 14 }
              },
              ticks: {
                callback: function(value) {
                  return parseFloat(value).toFixed(2)
                }
              }
            },
            y: {
              title: {
                display: true,
                text: 'Intensity (counts)',
                font: { size: 14 }
              },
              beginAtZero: true
            }
          },
          interaction: {
            intersect: false,
            mode: 'index'
          }
        }
      })
      
    } catch (error) {
      console.error('Error loading overlay chart:', error)
      const container = canvas.parentElement
      container.innerHTML = `
        <div class="alert alert-danger">
          <i class="bi bi-exclamation-triangle"></i>
          Error loading pattern data: ${error.message}
        </div>
      `
    } finally {
      if (loading) loading.style.display = 'none'
    }
  }
}