import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="well-layers"
export default class extends Controller {
  static targets = ["wellButton", "layerToggle", "statsContainer"]
  static values = { 
    config: Object,
    activeLayers: Array 
  }

  connect() {
    this.isLoading = true

    // Hide wells during loading
    this.setLoadingState(true)
    
    // Add Turbo event listeners for re-initialization after navigation
    this.setupTurboListeners()
    
    // Initialize after short delay to ensure DOM is ready
    setTimeout(() => {
      this.initializeController()
    }, 50)
  }

  disconnect() {
    // Clean up Turbo event listeners
    this.cleanupTurboListeners()
  }

  setupTurboListeners() {
    // Listen for Turbo navigation events
    this.handleTurboLoad = this.handleTurboLoad.bind(this)
    this.handleTurboRender = this.handleTurboRender.bind(this)
    
    document.addEventListener('turbo:load', this.handleTurboLoad)
    document.addEventListener('turbo:render', this.handleTurboRender)
  }

  cleanupTurboListeners() {
    document.removeEventListener('turbo:load', this.handleTurboLoad)
    document.removeEventListener('turbo:render', this.handleTurboRender)
  }

  handleTurboLoad() {
    this.refreshLayers()
  }

  handleTurboRender() {
    setTimeout(() => this.refreshLayers(), 100)
  }

  refreshLayers() {
    if (this.isLoading) return
    
    // Re-sync checkboxes in case they were reset
    this.syncCheckboxesWithActiveLayers()
    this.updateLayers()
  }

  initializeController() {
    if (Object.keys(this.configValue || {}).length === 0) {
      return
    }
    
    this.initializeLayers()
    this.bindEvents()
    
    // Set loading to false BEFORE calling updateLayers
    this.isLoading = false
    this.setLoadingState(false)
    
    this.updateLayers()
  }  initializeLayers() {
    // Try to restore from cookie first
    const savedLayers = this.getLayersFromCookie()
    const availableLayers = Object.keys(this.configValue)
    
    if (savedLayers.length > 0) {
      // Validate saved layers still exist in current config
      this.activeLayersValue = savedLayers.filter(layer => availableLayers.includes(layer))
    }
    
    // If no valid saved layers, use first available layer as default
    if (this.activeLayersValue.length === 0 && availableLayers.length > 0) {
      this.activeLayersValue = [availableLayers[0]]
    }
    
    // Update checkboxes to match restored state
    this.syncCheckboxesWithActiveLayers()
  }

  bindEvents() {
    // Layer toggle change events are handled by Stimulus automatically
  }

  // Stimulus callback when wellButton targets change (new buttons added/removed)
  wellButtonTargetsConnected() {
    // When new well buttons are connected after Turbo navigation, refresh layers
    if (!this.isLoading && this.activeLayersValue && this.activeLayersValue.length > 0) {
      setTimeout(() => this.updateLayers(), 10)
    }
  }

  layerToggleChanged(event) {
    const layerKey = event.target.value
    const isActive = event.target.checked
    
    this.toggleLayer(layerKey, isActive)
  }

  toggleLayer(layerKey, isActive) {
    if (isActive) {
      if (!this.activeLayersValue.includes(layerKey)) {
        this.activeLayersValue = [...this.activeLayersValue, layerKey]
      }
    } else {
      this.activeLayersValue = this.activeLayersValue.filter(layer => layer !== layerKey)
    }
    
    // Save to cookie
    this.saveLayersToCookie()
    
    this.updateLayers()
  }

  updateLayers() {
    // Skip updates during loading to prevent flashing
    if (this.isLoading) return
    
    // Update all well buttons based on active layers
    this.wellButtonTargets.forEach(button => {
      this.updateWellButtonMultiLayer(button)
    })

    // Update layer statistics
    this.updateAllLayerStats()
  }

  updateWellButtonMultiLayer(button) {
    const layerData = JSON.parse(button.dataset.layerData || '{}')
    
    // Find which active layers this well belongs to
    const activeLayersForWell = this.activeLayersValue.filter(layerKey => {
      const wellLayerInfo = layerData[layerKey]
      return wellLayerInfo && wellLayerInfo.active
    })

    if (activeLayersForWell.length === 0) {
      this.setWellInactive(button)
    } else if (activeLayersForWell.length === 1) {
      // Single layer - use solid color
      const layerConfig = this.configValue[activeLayersForWell[0]]
      this.setWellActive(button, layerConfig.color)
    } else {
      // Multiple layers - use gradient
      this.setWellMultiLayer(button, activeLayersForWell)
    }
  }

  setWellActive(button, color) {
    this.clearLayerIndicators(button)
    
    button.style.background = color
    button.style.color = this.getContrastColor(color)
    button.style.opacity = '1'
    button.style.border = '2px solid #dee2e6'
  }

  setWellInactive(button) {
    this.clearLayerIndicators(button)
    
    button.style.background = '#f8f9fa'
    button.style.color = '#6c757d'
    button.style.opacity = '0.6'
    button.style.border = '2px solid #dee2e6'
  }

  setWellMultiLayer(button, activeLayerKeys) {
    this.clearLayerIndicators(button)
    
    // Create gradient background from all active layer colors
    const colors = activeLayerKeys.map(key => this.configValue[key].color)
    const gradient = this.createLayerGradient(colors)
    
    button.style.background = gradient
    button.style.color = this.getContrastColorForGradient(colors)
    button.style.opacity = '1'
    button.style.border = '2px solid #dee2e6'
    
    // Add subtle layer count indicator for 3+ layers
    if (activeLayerKeys.length > 2) {
      this.addLayerCountIndicator(button, activeLayerKeys.length)
    }
  }

  clearLayerIndicators(button) {
    const existingIndicator = button.querySelector('.layer-count-indicator')
    if (existingIndicator) {
      existingIndicator.remove()
    }
    button.style.borderImage = ''
  }

  addLayerCountIndicator(button, count) {
    const indicator = document.createElement('span')
    indicator.className = 'layer-count-indicator'
    indicator.style.cssText = `
      position: absolute;
      top: 2px;
      right: 2px;
      background: rgba(0,0,0,0.7);
      color: white;
      font-size: 10px;
      padding: 1px 4px;
      border-radius: 8px;
      line-height: 1;
      z-index: 2;
    `
    indicator.textContent = count
    
    button.style.position = 'relative'
    button.appendChild(indicator)
  }

  createLayerGradient(colors) {
    if (colors.length === 1) {
      return colors[0]
    }
    
    if (colors.length === 2) {
      return `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 100%)`
    }
    
    if (colors.length === 3) {
      return `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 50%, ${colors[2]} 100%)`
    }
    
    // For 4+ layers, create a conic gradient
    const stopPercentage = 100 / colors.length
    const gradientStops = colors.map((color, index) => 
      `${color} ${index * stopPercentage}%`
    ).join(', ')
    
    return `conic-gradient(from 0deg, ${gradientStops}, ${colors[0]} 100%)`
  }

  getContrastColor(hexColor) {
    const r = parseInt(hexColor.slice(1, 3), 16)
    const g = parseInt(hexColor.slice(3, 5), 16)
    const b = parseInt(hexColor.slice(5, 7), 16)
    
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    
    return luminance > 0.5 ? '#000000' : '#ffffff'
  }

  getContrastColorForGradient(colors) {
    let totalLuminance = 0
    
    colors.forEach(color => {
      const r = parseInt(color.slice(1, 3), 16)
      const g = parseInt(color.slice(3, 5), 16)
      const b = parseInt(color.slice(5, 7), 16)
      const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
      totalLuminance += luminance
    })
    
    const averageLuminance = totalLuminance / colors.length
    return averageLuminance > 0.5 ? '#000000' : '#ffffff'
  }

  updateAllLayerStats() {
    if (!this.hasStatsContainerTarget) return

    if (this.activeLayersValue.length === 0) {
      this.statsContainerTarget.innerHTML = '<div class="text-muted">No layers selected</div>'
    } else {
      this.showMultiLayerStats()
    }
  }

  showMultiLayerStats() {
    const totalWells = this.wellButtonTargets.length
    let wellsWithAnyLayer = 0
    let wellsWithMultipleLayers = 0
    const layerStats = {}
    
    // Initialize layer stats
    this.activeLayersValue.forEach(layerKey => {
      layerStats[layerKey] = { active: 0, config: this.configValue[layerKey] }
    })
    
    // Calculate stats for each well
    this.wellButtonTargets.forEach(button => {
      const layerData = JSON.parse(button.dataset.layerData || '{}')
      const activeLayersForWell = this.activeLayersValue.filter(layerKey => {
        const wellLayerInfo = layerData[layerKey]
        return wellLayerInfo && wellLayerInfo.active
      })
      
      if (activeLayersForWell.length > 0) {
        wellsWithAnyLayer++
        if (activeLayersForWell.length > 1) {
          wellsWithMultipleLayers++
        }
        
        activeLayersForWell.forEach(layerKey => {
          layerStats[layerKey].active++
        })
      }
    })
    
    // Build stats HTML
    let html = ''
    
    // Individual layer stats
    this.activeLayersValue.forEach(layerKey => {
      const stats = layerStats[layerKey]
      const percentage = totalWells > 0 ? Math.round((stats.active / totalWells) * 100) : 0
      html += `
        <div class="d-flex justify-content-between mb-1">
          <span style="color: ${stats.config.color};">
            <i class="${stats.config.icon} me-1"></i>${stats.config.name}:
          </span>
          <strong>${stats.active} (${percentage}%)</strong>
        </div>
      `
    })
    
    // Summary stats
    if (this.activeLayersValue.length > 1) {
      const multiLayerPercentage = totalWells > 0 ? Math.round((wellsWithMultipleLayers / totalWells) * 100) : 0
      html += `
        <div class="border-top pt-2 mt-2">
          <div class="d-flex justify-content-between">
            <span class="text-info">Multi-layer wells:</span>
            <strong>${wellsWithMultipleLayers} (${multiLayerPercentage}%)</strong>
          </div>
        </div>
      `
    }
    
    const anyLayerPercentage = totalWells > 0 ? Math.round((wellsWithAnyLayer / totalWells) * 100) : 0
    html += `
      <div class="border-top pt-2 mt-2">
        <div class="d-flex justify-content-between">
          <span>Wells with data:</span>
          <strong>${wellsWithAnyLayer} (${anyLayerPercentage}%)</strong>
        </div>
        <div class="d-flex justify-content-between">
          <span>Total wells:</span>
          <strong>${totalWells}</strong>
        </div>
      </div>
    `
    
    this.statsContainerTarget.innerHTML = html
  }

  syncCheckboxesWithActiveLayers() {
    Object.keys(this.configValue).forEach(layerKey => {
      const checkbox = document.getElementById(`layer_${layerKey}`)
      if (checkbox) {
        checkbox.checked = this.activeLayersValue.includes(layerKey)
      }
    })
  }

  setLoadingState(isLoading) {
    const wellGrid = document.querySelector('#well-grid-container')
    
    if (isLoading) {
      if (wellGrid) {
        wellGrid.style.opacity = '0'
        wellGrid.style.transition = 'opacity 0.2s ease-in-out'
      }
      if (this.hasStatsContainerTarget) {
        this.statsContainerTarget.innerHTML = '<div class="text-muted">Loading...</div>'
      }
    } else {
      if (wellGrid) {
        setTimeout(() => {
          wellGrid.style.opacity = '1'
        }, 10)
      }
    }
  }

  // Cookie management methods
  saveLayersToCookie() {
    const cookieName = 'wellLayers'
    const cookieValue = JSON.stringify(this.activeLayersValue)
    const expiryDays = 30
    
    const date = new Date()
    date.setTime(date.getTime() + (expiryDays * 24 * 60 * 60 * 1000))
    const expires = `expires=${date.toUTCString()}`
    
    document.cookie = `${cookieName}=${cookieValue}; ${expires}; path=/; SameSite=Lax`
  }

  getLayersFromCookie() {
    const cookieName = 'wellLayers'
    const nameEQ = cookieName + "="
    const cookies = document.cookie.split(';')
    
    for (let i = 0; i < cookies.length; i++) {
      let cookie = cookies[i]
      while (cookie.charAt(0) === ' ') {
        cookie = cookie.substring(1, cookie.length)
      }
      if (cookie.indexOf(nameEQ) === 0) {
        try {
          const value = cookie.substring(nameEQ.length, cookie.length)
          return JSON.parse(value) || []
        } catch (e) {
          console.warn('Failed to parse layer cookie:', e)
          return []
        }
      }
    }
    return []
  }
}