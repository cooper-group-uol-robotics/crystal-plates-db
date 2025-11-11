import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="well-layers"
export default class extends Controller {
  static targets = ["wellButton", "layerToggle", "statsContainer", "colorScaleContainer", "colorScaleBar", "colorScaleMin", "colorScaleMax", "colorScaleName"]
  static values = {
    config: Object,
    activeLayers: Array
  }

  // Heatmap color palette setting: 'viridis', 'spectral', or 'inferno'
  static HEATMAP_PALETTE = 'inferno'

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
  } initializeLayers() {
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

    // Check if we have exactly one active custom attribute layer
    const activeCustomAttributeLayers = this.activeLayersValue.filter(layerKey => {
      const config = this.configValue[layerKey]
      return config && config.custom_attribute && config.data_type === 'numeric'
    })

    if (activeCustomAttributeLayers.length === 1 && this.activeLayersValue.length === 1) {
      // Single custom attribute layer - show text inputs
      this.showTextInputMode(activeCustomAttributeLayers[0])
    } else {
      // Multiple layers or non-custom layers - show buttons
      this.showButtonMode()
    }

    // Update layer statistics
    this.updateAllLayerStats()

    // Update color scale legend
    this.updateColorScale()
  }

  showTextInputMode(layerKey) {
    // Show text inputs for ALL wells, regardless of whether they have the attribute
    // Use a small delay to ensure all targets are properly initialized
    setTimeout(() => {
      // Try both Stimulus targets and direct selector as fallback
      let buttons = this.wellButtonTargets
      if (buttons.length === 0) {
        buttons = this.element.querySelectorAll('[data-well-layers-target="wellButton"]')
      }
      
      buttons.forEach((button, index) => {
        this.convertButtonToTextInput(button, layerKey)
      })
    }, 10)
  }

  showButtonMode() {
    // Try both Stimulus targets and direct selector as fallback
    let buttons = this.wellButtonTargets
    if (buttons.length === 0) {
      buttons = this.element.querySelectorAll('[data-well-layers-target="wellButton"]')
    }
    
    buttons.forEach(button => {
      this.convertTextInputToButton(button)
      this.updateWellButtonMultiLayer(button)
    })
  }

  convertButtonToTextInput(button, layerKey) {
    // Skip if already converted
    if (button.dataset.isTextInput === 'true') {
      this.updateTextInputValue(button, layerKey)
      return
    }

    const layerData = JSON.parse(button.dataset.layerData || '{}')
    const wellLayerInfo = layerData[layerKey]
    const currentValue = wellLayerInfo ? wellLayerInfo.value || '' : ''

    // Store original button properties
    button.dataset.originalInnerHTML = button.innerHTML
    button.dataset.isTextInput = 'true'

    // Create text input
    const input = document.createElement('input')
    input.type = 'text'
    input.value = currentValue
    input.className = 'well-value-input'
    input.style.cssText = `
      width: 100%;
      height: 100%;
      border: none;
      background: transparent;
      text-align: center;
      font-size: inherit;
      color: inherit;
      outline: none;
      padding: 0;
      margin: 0;
    `

    // Add event listeners
    input.addEventListener('blur', (e) => this.handleTextInputBlur(e, button, layerKey))
    input.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') {
        e.target.blur()
      }
    })
    input.addEventListener('focus', (e) => {
      e.target.select() // Select all text on focus
    })
    
    // Prevent modal from opening when clicking text input
    input.addEventListener('click', (e) => {
      e.stopPropagation()
      e.preventDefault()
    })

    // Replace button content with input
    button.innerHTML = ''
    button.appendChild(input)

    // Remove modal triggers from button when in text input mode
    button.removeAttribute('data-bs-toggle')
    button.removeAttribute('data-bs-target')

    // Update background color
    this.updateTextInputBackground(button, layerKey, currentValue)
  }

  convertTextInputToButton(button) {
    // Skip if not a text input
    if (button.dataset.isTextInput !== 'true') return

    // Restore original button content
    button.innerHTML = button.dataset.originalInnerHTML || ''
    button.dataset.isTextInput = 'false'
    delete button.dataset.originalInnerHTML
    
    // Restore modal triggers
    button.setAttribute('data-bs-toggle', 'modal')
    button.setAttribute('data-bs-target', '#wellImagesModal')
  }

  updateTextInputValue(button, layerKey) {
    const input = button.querySelector('.well-value-input')
    if (!input) return

    const layerData = JSON.parse(button.dataset.layerData || '{}')
    const wellLayerInfo = layerData[layerKey]
    const currentValue = wellLayerInfo ? wellLayerInfo.value || '' : ''

    input.value = currentValue
    this.updateTextInputBackground(button, layerKey, currentValue)
  }

  updateTextInputBackground(button, layerKey, value) {
    if (value === '' || value === null || value === undefined || isNaN(value)) {
      button.style.background = '#f8f9fa' // Default gray for missing values
      button.style.color = '#6c757d'
    } else {
      const color = this.getHeatmapColor(parseFloat(value), layerKey)
      button.style.background = color
      button.style.color = this.getContrastTextColor(color)
    }
  }

  async handleTextInputBlur(event, button, layerKey) {
    const input = event.target
    const newValue = input.value.trim()
    const wellId = button.dataset.wellId
    const plateBarcode = this.getPlateBarcode()

    // Update background color immediately
    this.updateTextInputBackground(button, layerKey, newValue)

    try {
      // Find the custom attribute ID
      const layerConfig = this.configValue[layerKey]
      const attributeId = layerConfig.attribute_id

      if (newValue === '' || newValue === null) {
        // Delete the score if value is empty
        await this.deleteWellScore(wellId, attributeId)
      } else {
        // Update the score
        await this.updateWellScore(wellId, attributeId, newValue)
      }

      // Update the layer data in the button
      this.updateButtonLayerData(button, layerKey, newValue)
      
      // Refresh colors of all wells since min/max range may have changed
      this.refreshAllWellColors(layerKey)
      
      // Update color scale and stats
      this.updateColorScale()
      this.updateAllLayerStats()

    } catch (error) {
      console.error('Error updating well score:', error)
      // Optionally show user feedback
      input.style.borderColor = 'red'
      setTimeout(() => {
        input.style.borderColor = ''
      }, 2000)
    }
  }

  updateButtonLayerData(button, layerKey, newValue) {
    const layerData = JSON.parse(button.dataset.layerData || '{}')
    
    if (!layerData[layerKey]) {
      layerData[layerKey] = {}
    }
    
    layerData[layerKey].value = newValue === '' ? null : parseFloat(newValue)
    layerData[layerKey].active = newValue !== '' && newValue !== null
    
    button.dataset.layerData = JSON.stringify(layerData)
  }

  refreshAllWellColors(layerKey) {
    // Refresh the background colors of all text inputs for the current layer
    // This is needed because changing one value can affect the min/max range
    // Try both Stimulus targets and direct selector as fallback
    let buttons = this.wellButtonTargets
    if (buttons.length === 0) {
      buttons = this.element.querySelectorAll('[data-well-layers-target="wellButton"]')
    }
    
    buttons.forEach(button => {
      // Only update if this button is currently a text input
      if (button.dataset.isTextInput === 'true') {
        const input = button.querySelector('.well-value-input')
        if (input) {
          this.updateTextInputBackground(button, layerKey, input.value)
        }
      }
    })
  }

  async updateWellScore(wellId, attributeId, value) {
    const plateBarcode = this.getPlateBarcode()
    const response = await fetch(`/api/v1/plates/${plateBarcode}/wells/${wellId}/well_scores`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({
        custom_attribute: { id: attributeId },
        value: value
      })
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }
  }

  async deleteWellScore(wellId, attributeId) {
    const plateBarcode = this.getPlateBarcode()
    
    // First get the well scores to find the score ID
    const scoresResponse = await fetch(`/api/v1/plates/${plateBarcode}/wells/${wellId}/well_scores`)
    if (!scoresResponse.ok) return
    
    const scoresData = await scoresResponse.json()
    const scoreToDelete = scoresData.data?.find(score => score.custom_attribute.id === attributeId)
    
    if (scoreToDelete) {
      const response = await fetch(`/api/v1/plates/${plateBarcode}/wells/${wellId}/well_scores/${scoreToDelete.id}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
    }
  }

  getPlateBarcode() {
    // Get plate barcode from data attribute
    return this.element.dataset.plateBarcode
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
      // Single layer - check if it's a custom attribute with numeric values
      const layerKey = activeLayersForWell[0]
      const layerConfig = this.configValue[layerKey]
      const wellLayerInfo = layerData[layerKey]

      if (layerConfig.custom_attribute && wellLayerInfo.value !== undefined && layerConfig.data_type === 'numeric') {
        // Use heatmap color for numeric custom attributes
        const color = this.getHeatmapColor(wellLayerInfo.value, layerKey)
        this.setWellActive(button, color)
      } else {
        // Use solid color for non-custom or non-numeric attributes
        this.setWellActive(button, layerConfig.color)
      }
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

  // Calculate heatmap color for numeric custom attribute values
  getHeatmapColor(value, layerKey) {
    if (value === null || value === undefined || isNaN(value)) {
      return '#f8f9fa' // Default gray for missing values
    }

    // Get all values for this layer to calculate min/max for normalization
    const allValues = this.getAllValuesForLayer(layerKey)

    if (allValues.length === 0) {
      return this.configValue[layerKey].color
    }

    const min = Math.min(...allValues)
    const max = Math.max(...allValues)

    // If all values are the same, use base color
    if (min === max) {
      return this.configValue[layerKey].color
    }

    // Normalize value to 0-1 range
    const normalizedValue = (value - min) / (max - min)

    // Use the selected color palette for heatmap
    if (this.constructor.HEATMAP_PALETTE === 'spectral') {
      return this.getSpectralColor(normalizedValue)
    } else if (this.constructor.HEATMAP_PALETTE === 'inferno') {
      return this.getInfernoColor(normalizedValue)
    } else {
      return this.getViridisColor(normalizedValue)
    }
  }

  // Viridis color palette for heatmaps (scientific color scheme)
  getViridisColor(t) {
    // Clamp t to [0, 1]
    t = Math.max(0, Math.min(1, t))
    
    // Viridis color palette interpolation
    // Based on matplotlib's viridis colormap
    const viridis = [
      [0.267004, 0.004874, 0.329415],
      [0.268510, 0.009605, 0.335427],
      [0.269944, 0.014625, 0.341379],
      [0.271305, 0.019942, 0.347269],
      [0.272594, 0.025563, 0.353093],
      [0.273809, 0.031497, 0.358853],
      [0.274952, 0.037752, 0.364543],
      [0.276022, 0.044167, 0.370164],
      [0.277018, 0.050344, 0.375715],
      [0.277941, 0.056324, 0.381191],
      [0.278791, 0.062145, 0.386592],
      [0.279566, 0.067836, 0.391917],
      [0.280267, 0.073417, 0.397163],
      [0.280894, 0.078907, 0.402329],
      [0.281446, 0.084320, 0.407414],
      [0.281924, 0.089666, 0.412415],
      [0.282327, 0.094955, 0.417331],
      [0.282656, 0.100196, 0.422160],
      [0.282910, 0.105393, 0.426902],
      [0.283091, 0.110553, 0.431554],
      [0.283197, 0.115680, 0.436115],
      [0.283229, 0.120777, 0.440584],
      [0.283187, 0.125848, 0.444960],
      [0.283072, 0.130895, 0.449241],
      [0.282884, 0.135920, 0.453427],
      [0.282623, 0.140926, 0.457517],
      [0.282290, 0.145912, 0.461510],
      [0.281887, 0.150881, 0.465405],
      [0.281412, 0.155834, 0.469201],
      [0.280868, 0.160771, 0.472899],
      [0.280255, 0.165693, 0.476498],
      [0.279574, 0.170599, 0.479997],
      [0.278826, 0.175490, 0.483397],
      [0.278012, 0.180367, 0.486697],
      [0.277134, 0.185228, 0.489898],
      [0.276194, 0.190074, 0.493001],
      [0.275191, 0.194905, 0.496005],
      [0.274128, 0.199721, 0.498911],
      [0.273006, 0.204520, 0.501721],
      [0.271828, 0.209303, 0.504434],
      [0.270595, 0.214069, 0.507052],
      [0.269308, 0.218818, 0.509577],
      [0.267968, 0.223549, 0.512008],
      [0.266580, 0.228262, 0.514349],
      [0.265145, 0.232956, 0.516599],
      [0.263663, 0.237631, 0.518762],
      [0.262138, 0.242286, 0.520837],
      [0.260571, 0.246922, 0.522828],
      [0.258965, 0.251537, 0.524736],
      [0.257322, 0.256130, 0.526563],
      [0.255645, 0.260703, 0.528312],
      [0.253935, 0.265254, 0.529983],
      [0.252194, 0.269783, 0.531579],
      [0.250425, 0.274290, 0.533103],
      [0.248629, 0.278775, 0.534556],
      [0.246811, 0.283237, 0.535941],
      [0.244972, 0.287675, 0.537260],
      [0.243113, 0.292092, 0.538516],
      [0.241237, 0.296485, 0.539709],
      [0.239346, 0.300855, 0.540844],
      [0.237441, 0.305202, 0.541921],
      [0.235526, 0.309527, 0.542944],
      [0.233603, 0.313828, 0.543914],
      [0.231674, 0.318106, 0.544834],
      [0.229739, 0.322361, 0.545706],
      [0.227802, 0.326594, 0.546532],
      [0.225863, 0.330805, 0.547314],
      [0.223925, 0.334994, 0.548053],
      [0.221989, 0.339161, 0.548752],
      [0.220057, 0.343307, 0.549413],
      [0.218130, 0.347432, 0.550038],
      [0.216210, 0.351535, 0.550627],
      [0.214298, 0.355619, 0.551184],
      [0.212395, 0.359683, 0.551710],
      [0.210503, 0.363727, 0.552206],
      [0.208623, 0.367752, 0.552675],
      [0.206756, 0.371758, 0.553117],
      [0.204903, 0.375746, 0.553533],
      [0.203063, 0.379716, 0.553925],
      [0.201239, 0.383670, 0.554294],
      [0.199430, 0.387607, 0.554642],
      [0.197636, 0.391528, 0.554969],
      [0.195860, 0.395433, 0.555276],
      [0.194100, 0.399323, 0.555565],
      [0.192357, 0.403199, 0.555836],
      [0.190631, 0.407061, 0.556089],
      [0.188923, 0.410910, 0.556326],
      [0.187231, 0.414746, 0.556547],
      [0.185556, 0.418570, 0.556753],
      [0.183898, 0.422383, 0.556944],
      [0.182256, 0.426184, 0.557120],
      [0.180629, 0.429975, 0.557282],
      [0.179019, 0.433756, 0.557430],
      [0.177423, 0.437527, 0.557565],
      [0.175841, 0.441290, 0.557685],
      [0.174274, 0.445044, 0.557792],
      [0.172719, 0.448791, 0.557885],
      [0.171176, 0.452530, 0.557965],
      [0.169646, 0.456262, 0.558030],
      [0.168126, 0.459988, 0.558082],
      [0.166617, 0.463708, 0.558119],
      [0.165117, 0.467423, 0.558141],
      [0.163625, 0.471133, 0.558148],
      [0.162142, 0.474838, 0.558140],
      [0.160665, 0.478540, 0.558115],
      [0.159194, 0.482237, 0.558073],
      [0.157729, 0.485932, 0.558013],
      [0.156270, 0.489624, 0.557936],
      [0.154815, 0.493313, 0.557840],
      [0.153364, 0.497000, 0.557724],
      [0.151918, 0.500685, 0.557587],
      [0.150476, 0.504369, 0.557430],
      [0.149039, 0.508051, 0.557250],
      [0.147607, 0.511733, 0.557049],
      [0.146180, 0.515413, 0.556823],
      [0.144759, 0.519093, 0.556572],
      [0.143343, 0.522773, 0.556295],
      [0.141935, 0.526453, 0.555991],
      [0.140536, 0.530132, 0.555659],
      [0.139147, 0.533812, 0.555298],
      [0.137770, 0.537492, 0.554906],
      [0.136408, 0.541173, 0.554483],
      [0.135066, 0.544853, 0.554029],
      [0.133743, 0.548535, 0.553541],
      [0.132444, 0.552216, 0.553018],
      [0.131172, 0.555899, 0.552459],
      [0.129933, 0.559582, 0.551864],
      [0.128729, 0.563265, 0.551229],
      [0.127568, 0.566949, 0.550556],
      [0.126453, 0.570633, 0.549841],
      [0.125394, 0.574318, 0.549086],
      [0.124395, 0.578002, 0.548287],
      [0.123463, 0.581687, 0.547445],
      [0.122606, 0.585371, 0.546557],
      [0.121831, 0.589055, 0.545623],
      [0.121148, 0.592739, 0.544641],
      [0.120565, 0.596422, 0.543611],
      [0.120092, 0.600104, 0.542530],
      [0.119738, 0.603785, 0.541400],
      [0.119512, 0.607464, 0.540218],
      [0.119423, 0.611141, 0.538982],
      [0.119483, 0.614817, 0.537692],
      [0.119699, 0.618490, 0.536347],
      [0.120081, 0.622161, 0.534946],
      [0.120638, 0.625828, 0.533488],
      [0.121380, 0.629492, 0.531973],
      [0.122312, 0.633153, 0.530398],
      [0.123444, 0.636809, 0.528763],
      [0.124780, 0.640461, 0.527068],
      [0.126326, 0.644107, 0.525311],
      [0.128087, 0.647749, 0.523491],
      [0.130067, 0.651384, 0.521608],
      [0.132268, 0.655014, 0.519661],
      [0.134692, 0.658636, 0.517649],
      [0.137339, 0.662252, 0.515571],
      [0.140210, 0.665859, 0.513427],
      [0.143303, 0.669459, 0.511215],
      [0.146616, 0.673050, 0.508936],
      [0.150148, 0.676631, 0.506589],
      [0.153894, 0.680203, 0.504172],
      [0.157851, 0.683765, 0.501686],
      [0.162016, 0.687316, 0.499129],
      [0.166383, 0.690856, 0.496502],
      [0.170948, 0.694384, 0.493803],
      [0.175707, 0.697900, 0.491033],
      [0.180653, 0.701402, 0.488189],
      [0.185783, 0.704891, 0.485273],
      [0.191090, 0.708366, 0.482284],
      [0.196571, 0.711827, 0.479221],
      [0.202219, 0.715272, 0.476084],
      [0.208030, 0.718701, 0.472873],
      [0.214000, 0.722114, 0.469588],
      [0.220124, 0.725509, 0.466226],
      [0.226397, 0.728888, 0.462789],
      [0.232815, 0.732247, 0.459277],
      [0.239374, 0.735588, 0.455688],
      [0.246070, 0.738910, 0.452024],
      [0.252899, 0.742211, 0.448284],
      [0.259857, 0.745492, 0.444467],
      [0.266941, 0.748751, 0.440573],
      [0.274149, 0.751988, 0.436601],
      [0.281477, 0.755203, 0.432552],
      [0.288921, 0.758394, 0.428426],
      [0.296479, 0.761561, 0.424223],
      [0.304148, 0.764704, 0.419943],
      [0.311925, 0.767822, 0.415586],
      [0.319809, 0.770914, 0.411152],
      [0.327796, 0.773980, 0.406640],
      [0.335885, 0.777018, 0.402049],
      [0.344074, 0.780029, 0.397381],
      [0.352360, 0.783011, 0.392636],
      [0.360741, 0.785964, 0.387814],
      [0.369214, 0.788888, 0.382914],
      [0.377779, 0.791781, 0.377939],
      [0.386433, 0.794644, 0.372886],
      [0.395174, 0.797475, 0.367757],
      [0.404001, 0.800275, 0.362552],
      [0.412913, 0.803041, 0.357269],
      [0.421908, 0.805774, 0.351910],
      [0.430983, 0.808473, 0.346476],
      [0.440137, 0.811138, 0.340967],
      [0.449368, 0.813768, 0.335384],
      [0.458674, 0.816363, 0.329727],
      [0.468053, 0.818921, 0.323998],
      [0.477504, 0.821444, 0.318195],
      [0.487026, 0.823929, 0.312321],
      [0.496615, 0.826376, 0.306377],
      [0.506271, 0.828786, 0.300362],
      [0.515992, 0.831158, 0.294279],
      [0.525776, 0.833491, 0.288127],
      [0.535621, 0.835785, 0.281908],
      [0.545524, 0.838039, 0.275626],
      [0.555484, 0.840254, 0.269281],
      [0.565498, 0.842430, 0.262877],
      [0.575563, 0.844566, 0.256415],
      [0.585678, 0.846661, 0.249897],
      [0.595839, 0.848717, 0.243329],
      [0.606045, 0.850733, 0.236712],
      [0.616293, 0.852709, 0.230052],
      [0.626579, 0.854645, 0.223353],
      [0.636902, 0.856542, 0.216620],
      [0.647257, 0.858400, 0.209861],
      [0.657642, 0.860219, 0.203082],
      [0.668054, 0.861999, 0.196293],
      [0.678489, 0.863742, 0.189503],
      [0.688944, 0.865448, 0.182725],
      [0.699415, 0.867117, 0.175971],
      [0.709898, 0.868751, 0.169257],
      [0.720391, 0.870350, 0.162603],
      [0.730889, 0.871916, 0.156029],
      [0.741388, 0.873449, 0.149561],
      [0.751884, 0.874951, 0.143228],
      [0.762373, 0.876424, 0.137064],
      [0.772852, 0.877868, 0.131109],
      [0.783315, 0.879285, 0.125405],
      [0.793760, 0.880678, 0.120005],
      [0.804182, 0.882046, 0.114965],
      [0.814576, 0.883393, 0.110347],
      [0.824940, 0.884720, 0.106217],
      [0.835270, 0.886029, 0.102646],
      [0.845561, 0.887322, 0.099702],
      [0.855810, 0.888601, 0.097452],
      [0.866013, 0.889868, 0.095953],
      [0.876168, 0.891125, 0.095250],
      [0.886271, 0.892374, 0.095374],
      [0.896320, 0.893616, 0.096335],
      [0.906311, 0.894855, 0.098125],
      [0.916242, 0.896091, 0.100717],
      [0.926106, 0.897330, 0.104071],
      [0.935904, 0.898570, 0.108131],
      [0.945636, 0.899815, 0.112838],
      [0.955300, 0.901065, 0.118128],
      [0.964894, 0.902323, 0.123941],
      [0.974417, 0.903590, 0.130215],
      [0.983868, 0.904867, 0.136897],
      [0.993248, 0.906157, 0.143936]
    ]
    
    // Find the appropriate color in the palette
    const index = Math.floor(t * (viridis.length - 1))
    const color = viridis[index]
    
    // Convert from [0,1] RGB to hex
    const r = Math.round(color[0] * 255)
    const g = Math.round(color[1] * 255)
    const b = Math.round(color[2] * 255)
    
    return this.rgbToHex(r, g, b)
  }

  // Inferno color palette for heatmaps (perceptually uniform)
  getInfernoColor(t) {
    // Clamp t to [0, 1]
    t = Math.max(0, Math.min(1, t))
    
    // Inferno color palette interpolation
    // Based on matplotlib's inferno colormap
    const inferno = [
      [0.001462, 0.000466, 0.013866],
      [0.002258, 0.001295, 0.018331],
      [0.003279, 0.002305, 0.023708],
      [0.004512, 0.003490, 0.029965],
      [0.005950, 0.004843, 0.037130],
      [0.007588, 0.006356, 0.044973],
      [0.009426, 0.008022, 0.052844],
      [0.011465, 0.009828, 0.060750],
      [0.013708, 0.011771, 0.068667],
      [0.016156, 0.013840, 0.076603],
      [0.018815, 0.016026, 0.084584],
      [0.021692, 0.018320, 0.092610],
      [0.024792, 0.020715, 0.100676],
      [0.028123, 0.023201, 0.108787],
      [0.031696, 0.025765, 0.116965],
      [0.035520, 0.028397, 0.125209],
      [0.039608, 0.031090, 0.133515],
      [0.043830, 0.033830, 0.141886],
      [0.048062, 0.036607, 0.150327],
      [0.052320, 0.039407, 0.158841],
      [0.056615, 0.042160, 0.167446],
      [0.060949, 0.044794, 0.176129],
      [0.065330, 0.047318, 0.184892],
      [0.069764, 0.049726, 0.193735],
      [0.074257, 0.052017, 0.202660],
      [0.078815, 0.054184, 0.211667],
      [0.083446, 0.056225, 0.220755],
      [0.088155, 0.058133, 0.229922],
      [0.092949, 0.059904, 0.239164],
      [0.097833, 0.061531, 0.248477],
      [0.102815, 0.063010, 0.257854],
      [0.107899, 0.064335, 0.267289],
      [0.113094, 0.065492, 0.276784],
      [0.118405, 0.066479, 0.286321],
      [0.123833, 0.067295, 0.295879],
      [0.129380, 0.067935, 0.305443],
      [0.135053, 0.068391, 0.315000],
      [0.140858, 0.068654, 0.324538],
      [0.146785, 0.068738, 0.334011],
      [0.152839, 0.068637, 0.343404],
      [0.159018, 0.068354, 0.352688],
      [0.165308, 0.067911, 0.361816],
      [0.171713, 0.067305, 0.370771],
      [0.178212, 0.066576, 0.379497],
      [0.184801, 0.065732, 0.387973],
      [0.191460, 0.064818, 0.396152],
      [0.198177, 0.063862, 0.404009],
      [0.204935, 0.062907, 0.411514],
      [0.211718, 0.061992, 0.418647],
      [0.218512, 0.061158, 0.425392],
      [0.225302, 0.060445, 0.431742],
      [0.232077, 0.059889, 0.437695],
      [0.238826, 0.059517, 0.443256],
      [0.245543, 0.059352, 0.448436],
      [0.252220, 0.059415, 0.453248],
      [0.258857, 0.059706, 0.457710],
      [0.265447, 0.060237, 0.461840],
      [0.271994, 0.060994, 0.465660],
      [0.278493, 0.061978, 0.469190],
      [0.284951, 0.063168, 0.472451],
      [0.291366, 0.064553, 0.475462],
      [0.297740, 0.066117, 0.478243],
      [0.304081, 0.067835, 0.480812],
      [0.310382, 0.069702, 0.483186],
      [0.316654, 0.071690, 0.485380],
      [0.322899, 0.073782, 0.487408],
      [0.329114, 0.075972, 0.489287],
      [0.335308, 0.078236, 0.491024],
      [0.341482, 0.080564, 0.492631],
      [0.347636, 0.082946, 0.494121],
      [0.353773, 0.085373, 0.495501],
      [0.359898, 0.087831, 0.496778],
      [0.366012, 0.090314, 0.497960],
      [0.372116, 0.092816, 0.499053],
      [0.378211, 0.095332, 0.500067],
      [0.384299, 0.097855, 0.501002],
      [0.390384, 0.100379, 0.501864],
      [0.396467, 0.102902, 0.502658],
      [0.402548, 0.105420, 0.503386],
      [0.408629, 0.107930, 0.504052],
      [0.414709, 0.110431, 0.504662],
      [0.420791, 0.112920, 0.505215],
      [0.426877, 0.115395, 0.505714],
      [0.432967, 0.117855, 0.506160],
      [0.439062, 0.120298, 0.506555],
      [0.445163, 0.122724, 0.506901],
      [0.451271, 0.125132, 0.507198],
      [0.457386, 0.127522, 0.507448],
      [0.463508, 0.129893, 0.507652],
      [0.469640, 0.132245, 0.507809],
      [0.475780, 0.134577, 0.507921],
      [0.481929, 0.136891, 0.507989],
      [0.488088, 0.139186, 0.508011],
      [0.494258, 0.141462, 0.507988],
      [0.500438, 0.143719, 0.507920],
      [0.506629, 0.145958, 0.507806],
      [0.512831, 0.148179, 0.507648],
      [0.519045, 0.150383, 0.507443],
      [0.525270, 0.152569, 0.507192],
      [0.531507, 0.154739, 0.506895],
      [0.537755, 0.156894, 0.506551],
      [0.544015, 0.159033, 0.506159],
      [0.550287, 0.161158, 0.505719],
      [0.556571, 0.163269, 0.505230],
      [0.562866, 0.165368, 0.504692],
      [0.569172, 0.167454, 0.504105],
      [0.575490, 0.169530, 0.503467],
      [0.581819, 0.171596, 0.502777],
      [0.588158, 0.173652, 0.502035],
      [0.594508, 0.175701, 0.501241],
      [0.600868, 0.177743, 0.500394],
      [0.607238, 0.179779, 0.499492],
      [0.613617, 0.181811, 0.498536],
      [0.620005, 0.183840, 0.497524],
      [0.626401, 0.185867, 0.496456],
      [0.632805, 0.187893, 0.495332],
      [0.639216, 0.189921, 0.494150],
      [0.645633, 0.191952, 0.492910],
      [0.652056, 0.193986, 0.491611],
      [0.658483, 0.196027, 0.490253],
      [0.664915, 0.198075, 0.488836],
      [0.671349, 0.200133, 0.487358],
      [0.677786, 0.202203, 0.485819],
      [0.684224, 0.204286, 0.484219],
      [0.690661, 0.206384, 0.482558],
      [0.697098, 0.208501, 0.480835],
      [0.703532, 0.210638, 0.479049],
      [0.709962, 0.212797, 0.477201],
      [0.716387, 0.214982, 0.475290],
      [0.722805, 0.217194, 0.473316],
      [0.729216, 0.219437, 0.471279],
      [0.735616, 0.221713, 0.469180],
      [0.742004, 0.224025, 0.467018],
      [0.748378, 0.226377, 0.464794],
      [0.754737, 0.228772, 0.462509],
      [0.761077, 0.231214, 0.460162],
      [0.767398, 0.233705, 0.457755],
      [0.773695, 0.236249, 0.455289],
      [0.779968, 0.238851, 0.452765],
      [0.786212, 0.241514, 0.450184],
      [0.792427, 0.244242, 0.447543],
      [0.798608, 0.247040, 0.444848],
      [0.804752, 0.249911, 0.442102],
      [0.810855, 0.252861, 0.439305],
      [0.816914, 0.255895, 0.436461],
      [0.822926, 0.259016, 0.433573],
      [0.828886, 0.262229, 0.430644],
      [0.834791, 0.265540, 0.427671],
      [0.840636, 0.268953, 0.424666],
      [0.846416, 0.272473, 0.421631],
      [0.852126, 0.276106, 0.418573],
      [0.857763, 0.279857, 0.415496],
      [0.863320, 0.283729, 0.412403],
      [0.868793, 0.287728, 0.409303],
      [0.874176, 0.291859, 0.406205],
      [0.879464, 0.296125, 0.403118],
      [0.884651, 0.300530, 0.400047],
      [0.889731, 0.305079, 0.397002],
      [0.894700, 0.309773, 0.393995],
      [0.899552, 0.314616, 0.391037],
      [0.904281, 0.319610, 0.388137],
      [0.908884, 0.324755, 0.385308],
      [0.913354, 0.330052, 0.382563],
      [0.917689, 0.335500, 0.379915],
      [0.921884, 0.341098, 0.377376],
      [0.925937, 0.346844, 0.374959],
      [0.929845, 0.352734, 0.372677],
      [0.933606, 0.358764, 0.370541],
      [0.937221, 0.364929, 0.368567],
      [0.940687, 0.371224, 0.366762],
      [0.944006, 0.377643, 0.365136],
      [0.947180, 0.384178, 0.363701],
      [0.950210, 0.390820, 0.362468],
      [0.953099, 0.397563, 0.361438],
      [0.955849, 0.404400, 0.360619],
      [0.958464, 0.411324, 0.360014],
      [0.960949, 0.418323, 0.359630],
      [0.963310, 0.425390, 0.359469],
      [0.965549, 0.432519, 0.359529],
      [0.967671, 0.439703, 0.359810],
      [0.969680, 0.446936, 0.360311],
      [0.971582, 0.454210, 0.361030],
      [0.973381, 0.461520, 0.361965],
      [0.975082, 0.468861, 0.363111],
      [0.976690, 0.476226, 0.364466],
      [0.978210, 0.483612, 0.366025],
      [0.979645, 0.491014, 0.367783],
      [0.981000, 0.498428, 0.369734],
      [0.982279, 0.505851, 0.371874],
      [0.983485, 0.513280, 0.374198],
      [0.984622, 0.520713, 0.376698],
      [0.985693, 0.528148, 0.379371],
      [0.986700, 0.535582, 0.382210],
      [0.987646, 0.543015, 0.385210],
      [0.988533, 0.550446, 0.388365],
      [0.989363, 0.557873, 0.391671],
      [0.990138, 0.565296, 0.395122],
      [0.990871, 0.572706, 0.398714],
      [0.991558, 0.580107, 0.402441],
      [0.992196, 0.587502, 0.406299],
      [0.992785, 0.594891, 0.410283],
      [0.993326, 0.602275, 0.414390],
      [0.993834, 0.609644, 0.418613],
      [0.994309, 0.616999, 0.422950],
      [0.994738, 0.624350, 0.427397],
      [0.995122, 0.631696, 0.431951],
      [0.995480, 0.639027, 0.436607],
      [0.995810, 0.646344, 0.441361],
      [0.996096, 0.653659, 0.446213],
      [0.996341, 0.660969, 0.451160],
      [0.996580, 0.668256, 0.456192],
      [0.996775, 0.675541, 0.461314],
      [0.996925, 0.682828, 0.466526],
      [0.997077, 0.690088, 0.471811],
      [0.997186, 0.697349, 0.477182],
      [0.997254, 0.704611, 0.482635],
      [0.997325, 0.711848, 0.488154],
      [0.997351, 0.719089, 0.493755],
      [0.997351, 0.726324, 0.499428],
      [0.997341, 0.733545, 0.505167],
      [0.997285, 0.740772, 0.510983],
      [0.997228, 0.747981, 0.516859],
      [0.997138, 0.755190, 0.522806],
      [0.997019, 0.762398, 0.528821],
      [0.996898, 0.769591, 0.534892],
      [0.996727, 0.776795, 0.541039],
      [0.996571, 0.783977, 0.547233],
      [0.996369, 0.791167, 0.553499],
      [0.996162, 0.798348, 0.559820],
      [0.995932, 0.805527, 0.566202],
      [0.995680, 0.812706, 0.572645],
      [0.995424, 0.819875, 0.579140],
      [0.995131, 0.827052, 0.585701],
      [0.994851, 0.834213, 0.592307],
      [0.994524, 0.841387, 0.598983],
      [0.994222, 0.848540, 0.605696],
      [0.993866, 0.855711, 0.612482],
      [0.993545, 0.862859, 0.619299],
      [0.993170, 0.870024, 0.626189],
      [0.992831, 0.877168, 0.633109],
      [0.992440, 0.884330, 0.640099],
      [0.992089, 0.891470, 0.647116],
      [0.991688, 0.898627, 0.654202],
      [0.991332, 0.905763, 0.661309],
      [0.990930, 0.912915, 0.668491],
      [0.990570, 0.920049, 0.675675],
      [0.990175, 0.927196, 0.682926],
      [0.989815, 0.934329, 0.690198],
      [0.989434, 0.941470, 0.697519],
      [0.989077, 0.948604, 0.704863],
      [0.988717, 0.955742, 0.712242],
      [0.988367, 0.962878, 0.719649],
      [0.988033, 0.970012, 0.727077],
      [0.987691, 0.977154, 0.734536],
      [0.987387, 0.984288, 0.742002],
      [0.987053, 0.991438, 0.749504]
    ]
    
    // Find the appropriate color in the palette
    const index = Math.floor(t * (inferno.length - 1))
    const color = inferno[index]
    
    // Convert from [0,1] RGB to hex
    const r = Math.round(color[0] * 255)
    const g = Math.round(color[1] * 255)
    const b = Math.round(color[2] * 255)
    
    return this.rgbToHex(r, g, b)
  }

  // Alternative: Spectral color palette for heatmaps
  getSpectralColor(t) {
    // Clamp t to [0, 1]
    t = Math.max(0, Math.min(1, t))
    
    // Spectral colormap: cool to warm colors
    const spectral = [
      [0.619608, 0.003922, 0.258824],
      [0.835294, 0.243137, 0.309804],
      [0.956863, 0.427451, 0.262745],
      [0.992157, 0.682353, 0.380392],
      [0.996078, 0.878431, 0.545098],
      [1.000000, 1.000000, 0.749020],
      [0.901961, 0.960784, 0.596078],
      [0.670588, 0.866667, 0.643137],
      [0.454902, 0.768627, 0.705882],
      [0.329412, 0.627451, 0.709804],
      [0.196078, 0.533333, 0.741176],
      [0.368627, 0.309804, 0.635294]
    ]
    
    const index = Math.floor(t * (spectral.length - 1))
    const color = spectral[index]
    
    const r = Math.round(color[0] * 255)
    const g = Math.round(color[1] * 255)
    const b = Math.round(color[2] * 255)
    
    return this.rgbToHex(r, g, b)
  }

  // Interpolate between two hex colors
  interpolateColor(color1, color2, factor) {
    const c1 = this.hexToRgb(color1)
    const c2 = this.hexToRgb(color2)

    const r = Math.round(c1.r + (c2.r - c1.r) * factor)
    const g = Math.round(c1.g + (c2.g - c1.g) * factor)
    const b = Math.round(c1.b + (c2.b - c1.b) * factor)

    return this.rgbToHex(r, g, b)
  }

  // Convert hex to RGB
  hexToRgb(hex) {
    const r = parseInt(hex.slice(1, 3), 16)
    const g = parseInt(hex.slice(3, 5), 16)
    const b = parseInt(hex.slice(5, 7), 16)
    return { r, g, b }
  }

  // Convert RGB to hex
  rgbToHex(r, g, b) {
    return "#" + ((1 << 24) + (r << 16) + (g << 8) + b).toString(16).slice(1)
  }

  // Get contrast text color (black or white) based on background color
  getContrastTextColor(hexColor) {
    // Convert hex to RGB
    const rgb = this.hexToRgb(hexColor)
    
    // Calculate relative luminance using the standard formula
    // https://www.w3.org/TR/WCAG20/#relativeluminancedef
    const getLuminance = (c) => {
      c = c / 255
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4)
    }
    
    const rLum = getLuminance(rgb.r)
    const gLum = getLuminance(rgb.g)
    const bLum = getLuminance(rgb.b)
    
    const luminance = 0.2126 * rLum + 0.7152 * gLum + 0.0722 * bLum
    
    // Return black text for light backgrounds, white text for dark backgrounds
    return luminance > 0.179 ? '#000000' : '#ffffff'
  }

  // Get all values for a custom attribute layer across all wells
  getAllValuesForLayer(layerKey) {
    const values = []

    this.wellButtonTargets.forEach(button => {
      const layerData = JSON.parse(button.dataset.layerData || '{}')
      const wellLayerInfo = layerData[layerKey]

      if (wellLayerInfo && wellLayerInfo.value !== null && wellLayerInfo.value !== undefined && !isNaN(wellLayerInfo.value)) {
        values.push(parseFloat(wellLayerInfo.value))
      }
    })

    return values
  }

  // Create and update color scale legend for numeric attributes
  updateColorScale() {
    // Find if we have any active custom attribute layers
    const activeCustomAttributeLayers = this.activeLayersValue.filter(layerKey => {
      const config = this.configValue[layerKey]
      return config && config.custom_attribute && config.data_type === 'numeric'
    })

    // Show/hide color scale container
    if (activeCustomAttributeLayers.length > 0 && this.hasColorScaleContainerTarget) {
      this.colorScaleContainerTarget.style.display = 'block'
      
      // Use the first active custom attribute layer for the scale
      const layerKey = activeCustomAttributeLayers[0]
      const config = this.configValue[layerKey]
      
      // Get all values for this layer
      const allValues = this.getAllValuesForLayer(layerKey)
      
      if (allValues.length > 0) {
        const min = Math.min(...allValues)
        const max = Math.max(...allValues)
        
        // Update scale labels
        if (this.hasColorScaleMinTarget) this.colorScaleMinTarget.textContent = min.toFixed(2)
        if (this.hasColorScaleMaxTarget) this.colorScaleMaxTarget.textContent = max.toFixed(2)
        
        // Create color gradient bar
        this.createColorGradientBar()
      }
    } else if (this.hasColorScaleContainerTarget) {
      this.colorScaleContainerTarget.style.display = 'none'
    }
  }

  // Create a color gradient bar showing the color scale
  createColorGradientBar() {
    if (!this.hasColorScaleBarTarget) return
    
    // Create gradient with multiple color stops
    const stops = []
    const numStops = 20 // Number of color stops for smooth gradient
    
    for (let i = 0; i <= numStops; i++) {
      const t = i / numStops
      let color
      
      // Use the same palette as the heatmap
      if (this.constructor.HEATMAP_PALETTE === 'spectral') {
        color = this.getSpectralColor(t)
      } else if (this.constructor.HEATMAP_PALETTE === 'inferno') {
        color = this.getInfernoColor(t)
      } else {
        color = this.getViridisColor(t)
      }
      
      const percentage = (t * 100).toFixed(1)
      stops.push(`${color} ${percentage}%`)
    }
    
    const gradient = `linear-gradient(to right, ${stops.join(', ')})`
    this.colorScaleBarTarget.style.background = gradient
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
      const config = this.configValue[layerKey]
      layerStats[layerKey] = {
        active: 0,
        config: config,
        values: config.custom_attribute && config.data_type === 'numeric' ? [] : null
      }
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

          // Collect values for custom numeric attributes
          if (layerStats[layerKey].values !== null) {
            const wellLayerInfo = layerData[layerKey]
            if (wellLayerInfo.value !== null && wellLayerInfo.value !== undefined && !isNaN(wellLayerInfo.value)) {
              layerStats[layerKey].values.push(parseFloat(wellLayerInfo.value))
            }
          }
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

      // Add statistics for custom numeric attributes
      if (stats.values && stats.values.length > 0) {
        const min = Math.min(...stats.values)
        const max = Math.max(...stats.values)
        const mean = stats.values.reduce((a, b) => a + b, 0) / stats.values.length

        html += `
          <div class="ps-3 small text-muted mb-2">
            Min: ${min.toFixed(2)} | Max: ${max.toFixed(2)} | Avg: ${mean.toFixed(2)}
          </div>
        `
      }
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