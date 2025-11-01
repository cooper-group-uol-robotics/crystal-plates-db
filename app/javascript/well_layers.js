// app/javascript/well_layers.js

export class WellLayerManager {
  constructor() {
    this.activeLayers = []; // Track multiple active layers
    this.layerConfig = {};
    this.wellButtons = [];
    this.isLoading = true; // Prevent visual updates during initialization
    this.init();
  }

  init() {
    // Hide wells during loading
    this.setLoadingState(true);
    
    this.loadLayerConfig();
    this.setInitialLayers();
    this.bindEvents();
    this.cacheWellButtons();
    
    // Use setTimeout to ensure all DOM updates are complete
    setTimeout(() => {
      this.isLoading = false; // Set this BEFORE calling updateLayers
      this.updateLayers();
      this.setLoadingState(false);
    }, 50);
  }

  loadLayerConfig() {
    // Layer configuration will be passed from Rails
    this.layerConfig = window.wellLayersConfig || {};
  }

  setInitialLayers() {
    // Try to restore from cookie first
    const savedLayers = this.getLayersFromCookie();
    const availableLayers = Object.keys(this.layerConfig);
    
    if (savedLayers.length > 0) {
      // Validate saved layers still exist in current config
      this.activeLayers = savedLayers.filter(layer => availableLayers.includes(layer));
    }
    
    // If no valid saved layers, use first available layer as default
    if (this.activeLayers.length === 0 && availableLayers.length > 0) {
      this.activeLayers = [availableLayers[0]];
    }
    
    // Update checkboxes to match restored state
    this.syncCheckboxesWithActiveLayers();
  }

  bindEvents() {
    // Layer toggle checkboxes
    document.addEventListener('change', (e) => {
      if (e.target.classList.contains('layer-toggle')) {
        const layerKey = e.target.value;
        this.toggleLayer(layerKey, e.target.checked);
      }
    });
  }

  cacheWellButtons() {
    this.wellButtons = Array.from(document.querySelectorAll('.well-layer-btn'));
  }

  toggleLayer(layerKey, isActive) {
    if (isActive) {
      if (!this.activeLayers.includes(layerKey)) {
        this.activeLayers.push(layerKey);
      }
    } else {
      this.activeLayers = this.activeLayers.filter(layer => layer !== layerKey);
    }
    
    // Save to cookie
    this.saveLayersToCookie();
    
    this.updateLayers();
  }

  updateLayers() {
    // Skip updates during loading to prevent flashing
    if (this.isLoading) return;
    
    // Update all well buttons based on active layers
    this.wellButtons.forEach(button => {
      this.updateWellButtonMultiLayer(button);
    });

    // Update layer statistics
    this.updateAllLayerStats();
  }

  updateWellButtonMultiLayer(button) {
    const layerData = JSON.parse(button.dataset.layerData || '{}');
    
    // Find which active layers this well belongs to
    const activeLayersForWell = this.activeLayers.filter(layerKey => {
      const wellLayerInfo = layerData[layerKey];
      return wellLayerInfo && wellLayerInfo.active;
    });

    if (activeLayersForWell.length === 0) {
      this.setWellInactive(button);
    } else if (activeLayersForWell.length === 1) {
      // Single layer - use solid color
      const layerConfig = this.layerConfig[activeLayersForWell[0]];
      this.setWellActive(button, layerConfig.color);
    } else {
      // Multiple layers - use stacked indicators
      this.setWellMultiLayer(button, activeLayersForWell);
    }
  }

  setWellActive(button, color) {
    // Clear any existing layer indicators
    this.clearLayerIndicators(button);
    
    button.style.background = color; // Use 'background' instead of 'backgroundColor' for gradient compatibility
    button.style.color = this.getContrastColor(color);
    button.style.opacity = '1';
    button.style.border = '2px solid #dee2e6';
  }

  setWellInactive(button) {
    // Clear any existing layer indicators
    this.clearLayerIndicators(button);
    
    button.style.background = '#f8f9fa'; // Use 'background' for consistency
    button.style.color = '#6c757d';
    button.style.opacity = '0.6';
    button.style.border = '2px solid #dee2e6';
  }

  setWellMultiLayer(button, activeLayerKeys) {
    // Clear any existing layer indicators
    this.clearLayerIndicators(button);
    
    // Create gradient background from all active layer colors
    const colors = activeLayerKeys.map(key => this.layerConfig[key].color);
    const gradient = this.createLayerGradient(colors);
    
    button.style.background = gradient;
    button.style.color = this.getContrastColorForGradient(colors);
    button.style.opacity = '1';
    button.style.border = '2px solid #dee2e6';
    
    // Add subtle layer count indicator for 3+ layers
    if (activeLayerKeys.length > 2) {
      this.addLayerCountIndicator(button, activeLayerKeys.length);
    }
  }

  clearLayerIndicators(button) {
    // Remove any existing layer indicators
    const existingIndicator = button.querySelector('.layer-count-indicator');
    if (existingIndicator) {
      existingIndicator.remove();
    }
    button.style.borderImage = '';
  }

  addLayerCountIndicator(button, count) {
    // Add a small badge showing layer count
    const indicator = document.createElement('span');
    indicator.className = 'layer-count-indicator';
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
    `;
    indicator.textContent = count;
    
    // Ensure button has relative positioning
    button.style.position = 'relative';
    button.appendChild(indicator);
  }

  createLayerGradient(colors) {
    if (colors.length === 1) {
      return colors[0];
    }
    
    if (colors.length === 2) {
      // Diagonal gradient for 2 layers
      return `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 100%)`;
    }
    
    if (colors.length === 3) {
      // Three-way gradient
      return `linear-gradient(135deg, ${colors[0]} 0%, ${colors[1]} 50%, ${colors[2]} 100%)`;
    }
    
    // For 4+ layers, create a radial gradient with color stops
    const stopPercentage = 100 / colors.length;
    const gradientStops = colors.map((color, index) => 
      `${color} ${index * stopPercentage}%`
    ).join(', ');
    
    return `conic-gradient(from 0deg, ${gradientStops}, ${colors[0]} 100%)`;
  }

  getContrastColorForGradient(colors) {
    // Calculate average luminance of all colors
    let totalLuminance = 0;
    
    colors.forEach(color => {
      const r = parseInt(color.slice(1, 3), 16);
      const g = parseInt(color.slice(3, 5), 16);
      const b = parseInt(color.slice(5, 7), 16);
      const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
      totalLuminance += luminance;
    });
    
    const averageLuminance = totalLuminance / colors.length;
    return averageLuminance > 0.5 ? '#000000' : '#ffffff';
  }

  // Cookie management methods
  saveLayersToCookie() {
    const cookieName = 'wellLayers';
    const cookieValue = JSON.stringify(this.activeLayers);
    const expiryDays = 30; // Cookie expires in 30 days
    
    const date = new Date();
    date.setTime(date.getTime() + (expiryDays * 24 * 60 * 60 * 1000));
    const expires = `expires=${date.toUTCString()}`;
    
    document.cookie = `${cookieName}=${cookieValue}; ${expires}; path=/; SameSite=Lax`;
  }

  getLayersFromCookie() {
    const cookieName = 'wellLayers';
    const nameEQ = cookieName + "=";
    const cookies = document.cookie.split(';');
    
    for (let i = 0; i < cookies.length; i++) {
      let cookie = cookies[i];
      while (cookie.charAt(0) === ' ') {
        cookie = cookie.substring(1, cookie.length);
      }
      if (cookie.indexOf(nameEQ) === 0) {
        try {
          const value = cookie.substring(nameEQ.length, cookie.length);
          return JSON.parse(value) || [];
        } catch (e) {
          console.warn('Failed to parse layer cookie:', e);
          return [];
        }
      }
    }
    return [];
  }

  syncCheckboxesWithActiveLayers() {
    // Update all layer checkboxes to match the active layers state
    Object.keys(this.layerConfig).forEach(layerKey => {
      const checkbox = document.getElementById(`layer_${layerKey}`);
      if (checkbox) {
        checkbox.checked = this.activeLayers.includes(layerKey);
      }
    });
  }

  setLoadingState(isLoading) {
    const wellGrid = document.querySelector('#well-grid-container');
    const layerStats = document.getElementById('layer-stats');
    
    if (isLoading) {
      // Add loading styles to prevent flash
      if (wellGrid) {
        wellGrid.style.opacity = '0';
        wellGrid.style.transition = 'opacity 0.2s ease-in-out';
      }
      if (layerStats) {
        layerStats.innerHTML = '<div class="text-muted">Loading...</div>';
      }
    } else {
      // Fade in the wells smoothly
      if (wellGrid) {
        setTimeout(() => {
          wellGrid.style.opacity = '1';
        }, 10);
      }
    }
  }

  getContrastColor(hexColor) {
    // Convert hex to RGB
    const r = parseInt(hexColor.slice(1, 3), 16);
    const g = parseInt(hexColor.slice(3, 5), 16);  
    const b = parseInt(hexColor.slice(5, 7), 16);
    
    // Calculate luminance
    const luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255;
    
    return luminance > 0.5 ? '#000000' : '#ffffff';
  }

  updateAllLayerStats() {
    const statsContainer = document.getElementById('layer-stats');
    if (!statsContainer) return;

    if (this.activeLayers.length === 0) {
      statsContainer.innerHTML = '<div class="text-muted">No layers selected</div>';
    } else {
      this.showMultiLayerStats(statsContainer);
    }
  }

  showMultiLayerStats(container) {
    const totalWells = this.wellButtons.length;
    let wellsWithAnyLayer = 0;
    let wellsWithMultipleLayers = 0;
    const layerStats = {};
    
    // Initialize layer stats
    this.activeLayers.forEach(layerKey => {
      layerStats[layerKey] = { active: 0, config: this.layerConfig[layerKey] };
    });
    
    // Calculate stats for each well
    this.wellButtons.forEach(button => {
      const layerData = JSON.parse(button.dataset.layerData || '{}');
      const activeLayersForWell = this.activeLayers.filter(layerKey => {
        const wellLayerInfo = layerData[layerKey];
        return wellLayerInfo && wellLayerInfo.active;
      });
      
      if (activeLayersForWell.length > 0) {
        wellsWithAnyLayer++;
        if (activeLayersForWell.length > 1) {
          wellsWithMultipleLayers++;
        }
        
        // Count each layer
        activeLayersForWell.forEach(layerKey => {
          layerStats[layerKey].active++;
        });
      }
    });
    
    // Build stats HTML
    let html = '';
    
    // Individual layer stats
    this.activeLayers.forEach(layerKey => {
      const stats = layerStats[layerKey];
      const percentage = totalWells > 0 ? Math.round((stats.active / totalWells) * 100) : 0;
      html += `
        <div class="d-flex justify-content-between mb-1">
          <span style="color: ${stats.config.color};">
            <i class="${stats.config.icon} me-1"></i>${stats.config.name}:
          </span>
          <strong>${stats.active} (${percentage}%)</strong>
        </div>
      `;
    });
    
    // Summary stats
    if (this.activeLayers.length > 1) {
      const multiLayerPercentage = totalWells > 0 ? Math.round((wellsWithMultipleLayers / totalWells) * 100) : 0;
      html += `
        <div class="border-top pt-2 mt-2">
          <div class="d-flex justify-content-between">
            <span class="text-info">Multi-layer wells:</span>
            <strong>${wellsWithMultipleLayers} (${multiLayerPercentage}%)</strong>
          </div>
        </div>
      `;
    }
    
    const anyLayerPercentage = totalWells > 0 ? Math.round((wellsWithAnyLayer / totalWells) * 100) : 0;
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
    `;
    
    container.innerHTML = html;
  }


}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  if (document.querySelector('.well-layer-btn')) {
    window.wellLayerManager = new WellLayerManager();
  }
});