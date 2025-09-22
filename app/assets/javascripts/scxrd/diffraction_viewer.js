// SCXRD Diffraction Viewer - Visual Heatmap Implementation
class ScxrdDiffractionViewer {
  constructor(containerId) {
    this.containerId = containerId;
    this.plotDiv = null;
    this.imageData = null;
    this.dimensions = null;
    this.metadata = null;
    this.heatmapInstance = null;
    this.currentIntensityRange = [0, 1000];
    this.currentZoom = 1;
    this.initialScale = 1;
  }

  getVisualHeatmap() {
    // Try both possible property names
    return window.VisualHeatmap || window.visualHeatmap;
  }

  async loadImageData(wellId, datasetId) {
    console.log(`Loading SCXRD image data for well ${wellId}, dataset ${datasetId}`);

    try {
      const url = `/wells/${wellId}/scxrd_datasets/${datasetId}/image_data`;
      console.log(`Fetching from: ${url}`);
      const response = await fetch(url);

      console.log(`Response status: ${response.status}`);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      console.log('Received data:', { success: data.success, dimensions: data.dimensions, dataLength: data.image_data?.length });

      if (!data.success) {
        throw new Error(data.error || 'Failed to load image data');
      }

      this.imageData = data.image_data;
      this.dimensions = data.dimensions;
      this.metadata = data.metadata;

      console.log(`Loaded ${this.dimensions[0]}x${this.dimensions[1]} diffraction image`);
      return true;
    } catch (error) {
      console.error('Error loading SCXRD image data:', error);
      this.showError(error.message);
      return false;
    }
  }

  createSuperpixelHeatmapData() {
    if (!this.imageData || !this.dimensions) {
      console.error('Missing image data or dimensions for creating superpixel data');
      return [];
    }

    const [width, height] = this.dimensions;
    const binSize = 2;
    const binnedWidth = Math.ceil(width / binSize);
    const binnedHeight = Math.ceil(height / binSize);

    console.log(`Binning ${width}x${height} image into ${binnedWidth}x${binnedHeight} superpixels (${binSize}x${binSize} each)`);

    const heatmapData = [];

    // Create superpixel bins
    for (let binY = 0; binY < binnedHeight; binY++) {
      for (let binX = 0; binX < binnedWidth; binX++) {
        let totalIntensity = 0;
        let pixelCount = 0;

        // Sum intensities within this superpixel
        for (let py = binY * binSize; py < Math.min((binY + 1) * binSize, height); py++) {
          for (let px = binX * binSize; px < Math.min((binX + 1) * binSize, width); px++) {
            const value = this.imageData[py * width + px];
            totalIntensity += value;
            if (value > 0) pixelCount++;
          }
        }

        // Only include superpixels with non-zero intensity
        if (totalIntensity > 0) {
          heatmapData.push({
            x: binX * binSize, // Store original coordinates for now
            y: height - (binY * binSize), // Flip Y coordinate to correct orientation
            value: totalIntensity // Use sum of intensities for better visibility
          });
        }
      }
    }

    console.log(`Generated ${heatmapData.length} superpixel data points from ${width}x${height} image (${binnedWidth}x${binnedHeight} grid)`);
    console.log(`Reduction: ${(this.imageData.length - heatmapData.length).toLocaleString()} fewer points`);
    console.log(`Sample superpixel data:`, heatmapData.slice(0, 10));

    return heatmapData;
  }

  plotImage() {
    console.log('plotImage() called, checking Visual Heatmap availability...');
    console.log('window.VisualHeatmap:', window.VisualHeatmap);
    console.log('window.visualHeatmap:', window.visualHeatmap);
    console.log('typeof VisualHeatmap:', typeof window.VisualHeatmap);
    console.log('typeof visualHeatmap:', typeof window.visualHeatmap);

    if (!this.getVisualHeatmap()) {
      console.error('Visual Heatmap library not available');
      console.error('Available window properties:', Object.keys(window).filter(key => key.toLowerCase().includes('visual') || key.toLowerCase().includes('heatmap')));
      this.showError('Visual Heatmap library not loaded. Trying to reload...');

      // Try to load the library dynamically as fallback
      this.loadVisualHeatmapFallback();
      return;
    }

    this.plotDiv = document.getElementById(this.containerId);
    if (!this.plotDiv) {
      console.error(`Plot container '${this.containerId}' not found`);
      return;
    }

    if (!this.imageData || !this.dimensions) {
      this.showError('No image data available');
      return;
    }

    const [width, height] = this.dimensions;

    // Create container with heatmap div and controls
    this.plotDiv.innerHTML = `
      <div style="position: relative; width: 100%; height: 100%; display: flex; flex-direction: column;">
        <div id="${this.containerId}-canvas" style="width: 100%; flex: 1; border: 1px solid #dee2e6; overflow: hidden; background: #000;"></div>
        <div id="${this.containerId}-controls" style="height: 50px; padding: 5px; background: #f8f9fa; border-top: 1px solid #dee2e6; flex-shrink: 0;">
          <!-- Controls will be added here -->
        </div>
      </div>
    `;

    const heatmapContainer = document.getElementById(`${this.containerId}-canvas`);

    // Create superpixel heatmap data
    const heatmapData = this.createSuperpixelHeatmapData();

    // Calculate intensity statistics for better scaling
    const sortedValues = this.imageData.filter(v => v > 0).sort((a, b) => a - b);
    const maxIntensity = sortedValues[sortedValues.length - 1] || 1;
    const p99 = sortedValues[Math.floor(sortedValues.length * 0.99)] || maxIntensity;

    this.currentIntensityRange = [0, p99];

    console.log(`Creating visual heatmap with ${heatmapData.length} data points`);
    console.log(`Intensity range: 0 to ${p99} (max: ${maxIntensity})`);

    // Calculate scale factor to fit the card width
    const containerRect = heatmapContainer.getBoundingClientRect();
    const containerWidth = containerRect.width - 2; // Account for border
    const scaleFactor = Math.min(containerWidth / width, 1.0); // Don't scale up, only down

    console.log(`Container width: ${containerWidth}px, Image width: ${width}px, Scale factor: ${scaleFactor}`);

    // Apply scaling to coordinates while keeping top-left anchored
    const scaledHeatmapData = heatmapData.map(point => ({
      x: point.x * scaleFactor,
      y: point.y * scaleFactor,
      value: point.value
    }));

    // Create heatmap instance using Visual Heatmap API
    try {
      const HeatmapConstructor = this.getVisualHeatmap();

      console.log(`First few scaled data points:`, scaledHeatmapData.slice(0, 5));
      console.log(`Data value range: min=${Math.min(...scaledHeatmapData.map(d => d.value))}, max=${Math.max(...scaledHeatmapData.map(d => d.value))}`);

      // Visual Heatmap expects a container ID/selector, not canvas element
      this.heatmapInstance = HeatmapConstructor(`#${this.containerId}-canvas`, {
        size: 3, // Fixed size (2 * 1.5 = 3, since binSize was 2)
        max: p99,
        min: 0,
        intensity: 1.0, // Keep intensity at 1.0 (valid range is 0-1)
        opacity: 1.0, // Full opacity
        zoom: 1.0, // No zoom - render at natural size
        gradient: [{
          color: [0, 0, 0, 1.0],        // Black with transparency
          offset: 0.0
        }, {
          color: [255, 0, 0, 1.0],      // Red
          offset: 0.33
        }, {
          color: [255, 255, 0, 1.0],    // Yellow
          offset: 0.66
        }, {
          color: [255, 255, 255, 1.0],      // White
          offset: 1.0
        }]
      });

      // Render the data
      console.log('Attempting to render data to heatmap instance...');
      console.log('Heatmap instance methods:', Object.keys(this.heatmapInstance));

      if (typeof this.heatmapInstance.renderData === 'function') {
        this.heatmapInstance.renderData(scaledHeatmapData);
        console.log('Data rendered with renderData()');
      } else if (typeof this.heatmapInstance.addData === 'function') {
        // Alternative API method
        this.heatmapInstance.addData(scaledHeatmapData);
        console.log('Data rendered with addData()');
      } else if (typeof this.heatmapInstance.setData === 'function') {
        // Another alternative API method
        this.heatmapInstance.setData({ data: scaledHeatmapData });
        console.log('Data rendered with setData()');
      } else {
        console.error('No suitable data rendering method found on heatmap instance');
        console.log('Available methods:', Object.keys(this.heatmapInstance));
      }

      // Force a render/repaint
      if (typeof this.heatmapInstance.render === 'function') {
        this.heatmapInstance.render();
      } else if (typeof this.heatmapInstance.repaint === 'function') {
        this.heatmapInstance.repaint();
      }

      // Store the initial scale for zoom controls (no scaling now)
      this.initialScale = 1.0;

      // Calculate average pixel intensity and set default to 10x average
      let totalIntensity = 0;
      let nonZeroPixels = 0;
      for (let i = 0; i < this.imageData.length; i++) {
        if (this.imageData[i] > 0) {
          totalIntensity += this.imageData[i];
          nonZeroPixels++;
        }
      }
      const averageIntensity = nonZeroPixels > 0 ? totalIntensity / nonZeroPixels : 100;
      this.defaultIntensity = averageIntensity * 50;
      this.maxSliderValue = this.defaultIntensity * 5;

      this.addControls();

      if (typeof this.heatmapInstance.setMax === 'function') {
        this.heatmapInstance.setMax(this.defaultIntensity);
        this.heatmapInstance.render();
        console.log(`Set initial intensity to: ${this.defaultIntensity.toFixed(2)} (10x average: ${averageIntensity.toFixed(2)})`);
      }

      // Add window resize handler to rescale the diffraction image
      this.setupResizeHandler();

      console.log('Visual heatmap created successfully');

    } catch (error) {
      console.error('Error creating visual heatmap:', error);
      this.showError('Failed to create diffraction image visualization');
    }
  }

  addControls() {
    const controlsDiv = document.getElementById(`${this.containerId}-controls`);
    if (!controlsDiv) return;

    const [width, height] = this.dimensions;
    // Fix: Don't spread large array - use manual calculation
    let maxIntensity = 0;
    for (let i = 0; i < this.imageData.length; i++) {
      if (this.imageData[i] > maxIntensity) {
        maxIntensity = this.imageData[i];
      }
    }

    const defaultValue = Math.round(this.defaultIntensity || 100);
    const maxValue = Math.round(this.maxSliderValue || 1000);

    controlsDiv.innerHTML = `
      <div class="d-flex align-items-center justify-content-center" style="font-size: 0.8rem;">
        <div class="d-flex align-items-center">
          <label class="me-2">Intensity:</label>
          <input type="range" id="${this.containerId}-intensity" class="form-range me-2" 
                 style="width: 120px;" min="1" max="${maxValue}" value="${defaultValue}">
          <span id="${this.containerId}-intensity-value">${defaultValue}</span>
        </div>
      </div>
    `;

    // Add event listener for intensity control
    const intensitySlider = document.getElementById(`${this.containerId}-intensity`);
    const intensityValue = document.getElementById(`${this.containerId}-intensity-value`);

    intensitySlider.addEventListener('input', (e) => {
      const sliderValue = parseInt(e.target.value);
      intensityValue.textContent = sliderValue;

      // Use the slider value directly as the intensity threshold (1-100)
      const newMax = sliderValue;
      this.currentIntensityRange[1] = newMax;

      // Update the heatmap's max value and re-render
      if (this.heatmapInstance) {
        console.log(`Intensity threshold set to: ${newMax}`);

        // Try different API methods for updating max value
        if (typeof this.heatmapInstance.setMax === 'function') {
          this.heatmapInstance.setMax(newMax);
        } else if (typeof this.heatmapInstance.configure === 'function') {
          this.heatmapInstance.configure({ max: newMax });
        } else if (typeof this.heatmapInstance.setConfig === 'function') {
          this.heatmapInstance.setConfig({ max: newMax });
        }

        // Force re-render
        if (typeof this.heatmapInstance.render === 'function') {
          this.heatmapInstance.render();
        } else if (typeof this.heatmapInstance.repaint === 'function') {
          this.heatmapInstance.repaint();
        }

        console.log(`Intensity threshold updated to: ${newMax}`);
      }
    });

    // Store reference for export function
    window[`scxrdViewer_${this.containerId.replace('-', '_')}`] = this;
  }

  setZoom(zoomLevel) {
    if (this.heatmapInstance) {
      // Apply zoom directly
      this.heatmapInstance.setZoom(zoomLevel);
      this.heatmapInstance.render();
      console.log(`Zoom set to ${zoomLevel}x`);
    }
  }

  loadVisualHeatmapFallback() {
    console.log('Attempting to load Visual Heatmap library dynamically...');

    // Try multiple CDN sources
    const cdnUrls = [
      'https://unpkg.com/visual-heatmap@2.2.0/dist/visualHeatmap.min.js',
      'https://cdn.jsdelivr.net/npm/visual-heatmap@2.2.0/dist/visualHeatmap.min.js',
      'https://cdnjs.cloudflare.com/ajax/libs/visual-heatmap/2.2.0/visualHeatmap.min.js'
    ];

    let currentIndex = 0;

    const tryNextCdn = () => {
      if (currentIndex >= cdnUrls.length) {
        this.showError('Unable to load Visual Heatmap library from any CDN source. Please check your internet connection.');
        return;
      }

      const script = document.createElement('script');
      script.src = cdnUrls[currentIndex];
      script.onload = () => {
        console.log(`Visual Heatmap loaded successfully from: ${cdnUrls[currentIndex]}`);
        console.log('window.VisualHeatmap now available:', !!window.VisualHeatmap);
        console.log('window.visualHeatmap now available:', !!window.visualHeatmap);
        // Retry plotting
        setTimeout(() => this.plotImage(), 100);
      };
      script.onerror = () => {
        console.error(`Failed to load from: ${cdnUrls[currentIndex]}`);
        currentIndex++;
        tryNextCdn();
      };
      document.head.appendChild(script);
    };

    tryNextCdn();
  }

  exportImage() {
    if (!this.heatmapInstance) {
      console.error('No heatmap instance available for export');
      return;
    }

    try {
      // Use Visual Heatmap's built-in export functionality
      this.heatmapInstance.toBlob('image/png', 0.92).then(blob => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `scxrd_diffraction_${Date.now()}.png`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log('Image export completed');
      }).catch(error => {
        console.error('Error exporting image:', error);
      });

    } catch (error) {
      console.error('Error exporting image:', error);
    }
  }

  showError(message) {
    const plotDiv = document.getElementById(this.containerId);
    if (plotDiv) {
      plotDiv.innerHTML = `
        <div class="alert alert-danger m-3" role="alert">
          <h6>Error Loading Diffraction Image</h6>
          <p class="mb-0">${message}</p>
        </div>
      `;
    }
  }

  showLoading() {
    const plotDiv = document.getElementById(this.containerId);
    if (plotDiv) {
      plotDiv.innerHTML = `
        <div class="d-flex justify-content-center align-items-center" style="height: 30vw;">
          <div class="text-center">
            <div class="spinner-border text-primary" role="status">
              <span class="visually-hidden">Loading...</span>
            </div>
            <div class="mt-2">Loading diffraction image...</div>
          </div>
        </div>
      `;
    }
  }

  setupResizeHandler() {
    // Remove any existing resize handler for this instance
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler);
    }

    // Create a debounced resize handler
    let resizeTimeout;
    this.resizeHandler = () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        this.handleResize();
      }, 250); // Debounce for 250ms
    };

    // Add the resize event listener
    window.addEventListener('resize', this.resizeHandler);
    console.log('Resize handler setup for diffraction image viewer');
  }

  handleResize() {
    if (!this.heatmapInstance || !this.imageData || !this.dimensions) {
      console.log('Missing data for resize - heatmap instance, image data, or dimensions');
      return;
    }

    try {
      console.log('Handling window resize for diffraction image - completely redrawing');

      // Get the current container dimensions
      const container = document.getElementById(this.containerId);
      if (!container) {
        console.log('Container not found for resize');
        return;
      }

      // Get new container dimensions
      const containerRect = container.getBoundingClientRect();
      console.log(`New container dimensions: ${containerRect.width}x${containerRect.height}`);

      // Properly destroy the old heatmap instance and clear the canvas
      if (this.heatmapInstance) {
        // Try multiple destroy methods
        if (typeof this.heatmapInstance.destroy === 'function') {
          this.heatmapInstance.destroy();
        } else if (typeof this.heatmapInstance.clear === 'function') {
          this.heatmapInstance.clear();
        }
        this.heatmapInstance = null;
      }

      // Clear the canvas container completely
      const canvasContainer = document.getElementById(`${this.containerId}-canvas`);
      if (canvasContainer) {
        // Remove all child elements (canvas, etc.)
        canvasContainer.innerHTML = '';
        console.log('Cleared canvas container for resize');
      }

      // Get heatmap constructor
      const HeatmapConstructor = this.getVisualHeatmap();
      if (!HeatmapConstructor) {
        console.error('VisualHeatmap not available for resize');
        return;
      }

      // Recreate heatmap instance with new container size
      this.heatmapInstance = HeatmapConstructor(`#${this.containerId}-canvas`, {
        width: containerRect.width,
        height: containerRect.height,
        canvas: true,
        radius: Math.max(1, Math.min(containerRect.width, containerRect.height) * 0.015),
        maxOpacity: 0.8,
        minOpacity: 0.1,
        blur: 0.9,
        size: 3,
        gradient: [{
          color: [0, 0, 0, 1.0],        // Black with transparency
          offset: 0.0
        }, {
          color: [255, 0, 0, 1.0],      // Red
          offset: 0.33
        }, {
          color: [255, 255, 0, 1.0],    // Yellow
          offset: 0.66
        }, {
          color: [255, 255, 255, 1.0],  // White
          offset: 1.0
        }]
      });

      // Recalculate scaling factors for the new container size
      const [originalWidth, originalHeight] = this.dimensions;
      const scaleX = containerRect.width / originalWidth;
      const scaleY = containerRect.height / originalHeight;
      console.log(`Rescaling points: scaleX=${scaleX.toFixed(3)}, scaleY=${scaleY.toFixed(3)}`);

      // Recreate superpixel heatmap data with new scaling
      const heatmapData = this.createSuperpixelHeatmapData();

      // Scale the heatmap data points to new container size
      const scaledHeatmapData = heatmapData.map(point => ({
        x: point.x * scaleX,
        y: point.y * scaleY,
        value: point.value
      }));

      console.log(`Redrawing with ${scaledHeatmapData.length} rescaled data points`);

      // Apply the rescaled data to the new heatmap instance
      if (typeof this.heatmapInstance.renderData === 'function') {
        this.heatmapInstance.renderData(scaledHeatmapData);
      } else if (typeof this.heatmapInstance.addData === 'function') {
        scaledHeatmapData.forEach(point => this.heatmapInstance.addData(point));
      } else if (typeof this.heatmapInstance.setData === 'function') {
        this.heatmapInstance.setData({ data: scaledHeatmapData });
      }

      // Apply current intensity settings to the new instance
      if (typeof this.heatmapInstance.setMax === 'function') {
        this.heatmapInstance.setMax(this.defaultIntensity || 100);
      }

      // Render the new heatmap
      if (typeof this.heatmapInstance.render === 'function') {
        this.heatmapInstance.render();
      } else if (typeof this.heatmapInstance.repaint === 'function') {
        this.heatmapInstance.repaint();
      }

      console.log('Diffraction image completely redrawn and rescaled successfully');

    } catch (error) {
      console.error('Error handling resize:', error);
    }
  }

  destroy() {
    // Clean up resize handler when viewer is destroyed
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler);
      this.resizeHandler = null;
    }
  }
}

// Make available globally
window.ScxrdDiffractionViewer = ScxrdDiffractionViewer;
console.log('ScxrdDiffractionViewer (Visual Heatmap) defined');