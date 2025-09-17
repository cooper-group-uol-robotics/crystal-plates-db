// SCXRD Diffraction Viewer using Visual Heatmap
// Replaces Plotly.js for better performance with large datasets

class ScxrdDiffractionViewer {
  constructor(containerId, dataUrl, metadata = {}) {
    this.containerId = containerId;
    this.dataUrl = dataUrl;
    this.metadata = metadata;
    this.heatmapInstance = null;
    this.currentData = null;
    this.intensityRange = [0, 100];
    this.currentZoom = 1;
    
    // Initialize viewer
    this.init();
  }

  async init() {
    try {
      // Wait for visual-heatmap library to be available
      await this.waitForVisualHeatmap();
      
      // Load and process data
      await this.loadData();
      
      // Create visualization
      this.createVisualization();
      
      // Add interactive controls
      this.addControls();
      
      console.log('SCXRD Diffraction Viewer initialized successfully');
    } catch (error) {
      console.error('Failed to initialize SCXRD Diffraction Viewer:', error);
      this.showError(error.message);
    }
  }

  async waitForVisualHeatmap() {
    return new Promise((resolve, reject) => {
      const checkLibrary = () => {
        if (window.Heatmap) {
          resolve();
        } else if (document.readyState === 'complete') {
          reject(new Error('Visual-heatmap library not available. Please check CDN connection.'));
        } else {
          setTimeout(checkLibrary, 100);
        }
      };
      checkLibrary();
    });
  }

  async loadData() {
    try {
      const response = await fetch(this.dataUrl);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      
      const data = await response.json();
      
      // Convert 2D array to visual-heatmap format
      this.currentData = this.convertToHeatmapFormat(data);
      
      // Calculate intensity statistics
      this.calculateIntensityRange();
      
      console.log(`Loaded ${this.currentData.length} data points for visualization`);
    } catch (error) {
      throw new Error(`Failed to load diffraction data: ${error.message}`);
    }
  }

  convertToHeatmapFormat(data2D) {
    const heatmapData = [];
    
    if (!Array.isArray(data2D) || !Array.isArray(data2D[0])) {
      throw new Error('Invalid data format: expected 2D array');
    }
    
    const height = data2D.length;
    const width = data2D[0].length;
    
    for (let y = 0; y < height; y++) {
      for (let x = 0; x < width; x++) {
        if (data2D[y] && data2D[y][x] !== undefined) {
          heatmapData.push({
            x: x,
            y: y,
            value: data2D[y][x]
          });
        }
      }
    }
    
    return heatmapData;
  }

  calculateIntensityRange() {
    if (!this.currentData || this.currentData.length === 0) {
      this.intensityRange = [0, 100];
      return;
    }
    
    const values = this.currentData.map(point => point.value);
    const min = Math.min(...values);
    const max = Math.max(...values);
    
    this.intensityRange = [min, max];
    console.log(`Intensity range: ${min} - ${max}`);
  }

  createVisualization() {
    const container = document.getElementById(this.containerId);
    if (!container) {
      throw new Error(`Container with ID '${this.containerId}' not found`);
    }

    // Clear any existing content
    container.innerHTML = '';

    // Create heatmap container
    const heatmapContainer = document.createElement('div');
    heatmapContainer.id = `${this.containerId}_heatmap`;
    heatmapContainer.style.width = '100%';
    heatmapContainer.style.height = '600px';
    heatmapContainer.style.border = '1px solid #ddd';
    heatmapContainer.style.borderRadius = '4px';
    container.appendChild(heatmapContainer);

    // Initialize visual-heatmap
    this.heatmapInstance = new window.Heatmap({
      container: heatmapContainer,
      data: this.currentData,
      options: {
        colorScheme: 'viridis',
        showAxes: true,
        showColorbar: true,
        width: 800,
        height: 600,
        margin: { top: 20, right: 80, bottom: 40, left: 40 }
      }
    });

    console.log('Visual heatmap created successfully');
  }

  addControls() {
    const container = document.getElementById(this.containerId);
    if (!container) return;

    // Create controls panel
    const controlsPanel = document.createElement('div');
    controlsPanel.className = 'heatmap-controls mt-3';
    controlsPanel.innerHTML = `
      <div class="card">
        <div class="card-header">
          <h6 class="mb-0">Visualization Controls</h6>
        </div>
        <div class="card-body">
          <div class="row">
            <div class="col-md-4">
              <label for="${this.containerId}_intensity_min" class="form-label">Min Intensity:</label>
              <input type="range" class="form-range" id="${this.containerId}_intensity_min" 
                     min="${this.intensityRange[0]}" max="${this.intensityRange[1]}" 
                     value="${this.intensityRange[0]}" step="1">
              <small class="form-text text-muted">
                <span id="${this.containerId}_min_value">${this.intensityRange[0]}</span>
              </small>
            </div>
            <div class="col-md-4">
              <label for="${this.containerId}_intensity_max" class="form-label">Max Intensity:</label>
              <input type="range" class="form-range" id="${this.containerId}_intensity_max" 
                     min="${this.intensityRange[0]}" max="${this.intensityRange[1]}" 
                     value="${this.intensityRange[1]}" step="1">
              <small class="form-text text-muted">
                <span id="${this.containerId}_max_value">${this.intensityRange[1]}</span>
              </small>
            </div>
            <div class="col-md-4">
              <label for="${this.containerId}_zoom" class="form-label">Zoom:</label>
              <input type="range" class="form-range" id="${this.containerId}_zoom" 
                     min="0.5" max="3" value="1" step="0.1">
              <small class="form-text text-muted">
                <span id="${this.containerId}_zoom_value">1.0x</span>
              </small>
            </div>
          </div>
          <div class="row mt-3">
            <div class="col-md-12">
              <button type="button" class="btn btn-secondary btn-sm me-2" id="${this.containerId}_reset">
                Reset View
              </button>
              <button type="button" class="btn btn-primary btn-sm me-2" id="${this.containerId}_export">
                Export Image
              </button>
              <div class="d-inline-block">
                <small class="text-muted">
                  Data points: ${this.currentData ? this.currentData.length.toLocaleString() : 0}
                  ${this.metadata.dimensions ? ` | Size: ${this.metadata.dimensions}` : ''}
                </small>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;

    container.appendChild(controlsPanel);

    // Attach event listeners
    this.attachControlEvents();
  }

  attachControlEvents() {
    const minSlider = document.getElementById(`${this.containerId}_intensity_min`);
    const maxSlider = document.getElementById(`${this.containerId}_intensity_max`);
    const zoomSlider = document.getElementById(`${this.containerId}_zoom`);
    const resetButton = document.getElementById(`${this.containerId}_reset`);
    const exportButton = document.getElementById(`${this.containerId}_export`);

    // Intensity range controls
    if (minSlider) {
      minSlider.addEventListener('input', (e) => {
        const value = parseFloat(e.target.value);
        document.getElementById(`${this.containerId}_min_value`).textContent = value;
        this.updateIntensityRange(value, null);
      });
    }

    if (maxSlider) {
      maxSlider.addEventListener('input', (e) => {
        const value = parseFloat(e.target.value);
        document.getElementById(`${this.containerId}_max_value`).textContent = value;
        this.updateIntensityRange(null, value);
      });
    }

    // Zoom control
    if (zoomSlider) {
      zoomSlider.addEventListener('input', (e) => {
        const value = parseFloat(e.target.value);
        document.getElementById(`${this.containerId}_zoom_value`).textContent = `${value.toFixed(1)}x`;
        this.updateZoom(value);
      });
    }

    // Reset button
    if (resetButton) {
      resetButton.addEventListener('click', () => this.resetView());
    }

    // Export button
    if (exportButton) {
      exportButton.addEventListener('click', () => this.exportImage());
    }
  }

  updateIntensityRange(minValue = null, maxValue = null) {
    if (!this.heatmapInstance) return;

    try {
      // Update range values
      if (minValue !== null) this.intensityRange[0] = minValue;
      if (maxValue !== null) this.intensityRange[1] = maxValue;

      // Apply intensity filtering to heatmap
      if (this.heatmapInstance.setIntensityRange) {
        this.heatmapInstance.setIntensityRange(this.intensityRange[0], this.intensityRange[1]);
      }
    } catch (error) {
      console.warn('Failed to update intensity range:', error);
    }
  }

  updateZoom(zoomLevel) {
    if (!this.heatmapInstance) return;

    try {
      this.currentZoom = zoomLevel;
      
      // Apply zoom to heatmap
      if (this.heatmapInstance.setZoom) {
        this.heatmapInstance.setZoom(zoomLevel);
      }
    } catch (error) {
      console.warn('Failed to update zoom:', error);
    }
  }

  resetView() {
    try {
      // Reset intensity range
      this.intensityRange = [
        Math.min(...this.currentData.map(p => p.value)),
        Math.max(...this.currentData.map(p => p.value))
      ];

      // Reset zoom
      this.currentZoom = 1;

      // Update UI controls
      const minSlider = document.getElementById(`${this.containerId}_intensity_min`);
      const maxSlider = document.getElementById(`${this.containerId}_intensity_max`);
      const zoomSlider = document.getElementById(`${this.containerId}_zoom`);

      if (minSlider) {
        minSlider.value = this.intensityRange[0];
        document.getElementById(`${this.containerId}_min_value`).textContent = this.intensityRange[0];
      }
      if (maxSlider) {
        maxSlider.value = this.intensityRange[1];
        document.getElementById(`${this.containerId}_max_value`).textContent = this.intensityRange[1];
      }
      if (zoomSlider) {
        zoomSlider.value = 1;
        document.getElementById(`${this.containerId}_zoom_value`).textContent = '1.0x';
      }

      // Reset heatmap view
      if (this.heatmapInstance && this.heatmapInstance.reset) {
        this.heatmapInstance.reset();
      }

      console.log('View reset to defaults');
    } catch (error) {
      console.error('Failed to reset view:', error);
    }
  }

  exportImage() {
    try {
      if (this.heatmapInstance && this.heatmapInstance.export) {
        const filename = `scxrd_diffraction_${Date.now()}.png`;
        this.heatmapInstance.export('png', filename);
        console.log(`Exported image as ${filename}`);
      } else {
        // Fallback: use canvas toDataURL
        const canvas = document.querySelector(`#${this.containerId}_heatmap canvas`);
        if (canvas) {
          const link = document.createElement('a');
          link.download = `scxrd_diffraction_${Date.now()}.png`;
          link.href = canvas.toDataURL();
          link.click();
          console.log('Exported image using canvas fallback');
        } else {
          throw new Error('No canvas element found for export');
        }
      }
    } catch (error) {
      console.error('Failed to export image:', error);
      alert('Export failed. Please try again.');
    }
  }

  showError(message) {
    const container = document.getElementById(this.containerId);
    if (container) {
      container.innerHTML = `
        <div class="alert alert-danger" role="alert">
          <h6>SCXRD Visualization Error</h6>
          <p class="mb-0">${message}</p>
        </div>
      `;
    }
  }

  // Public API methods
  updateData(newDataUrl) {
    this.dataUrl = newDataUrl;
    this.loadData().then(() => {
      this.createVisualization();
    }).catch(error => {
      console.error('Failed to update data:', error);
      this.showError(error.message);
    });
  }

  destroy() {
    if (this.heatmapInstance && this.heatmapInstance.destroy) {
      this.heatmapInstance.destroy();
    }
    
    const container = document.getElementById(this.containerId);
    if (container) {
      container.innerHTML = '';
    }
    
    this.heatmapInstance = null;
    this.currentData = null;
  }
}

// Export for global use
window.ScxrdDiffractionViewer = ScxrdDiffractionViewer;