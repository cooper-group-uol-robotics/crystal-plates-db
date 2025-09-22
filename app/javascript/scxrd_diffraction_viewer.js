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
    this.diffractionImages = [];
    this.currentImageIndex = 0;
    
    // Image preloading cache
    this.imageCache = new Map(); // imageId -> {data, dimensions, metadata, timestamp}
    this.maxCacheSize = 50;
    this.preloadQueue = [];
    this.isPreloading = false;

    // Initialize viewer
    this.init();
  }

  async init() {
    try {
      // Wait for visual-heatmap library to be available
      await this.waitForVisualHeatmap();

      // Load diffraction images list for navigation (if available)
      await this.loadDiffractionImagesList();

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

  async loadDiffractionImagesList() {
    try {
      // Extract dataset information from the current URL to get list of images
      if (this.metadata.run_number && this.metadata.image_number) {
        // Try to get the index URL by modifying the current URL
        const indexUrl = this.dataUrl.replace(/\/\d+\/image_data$/, '');

        const response = await fetch(indexUrl, {
          headers: {
            'Accept': 'application/json'
          }
        });

        if (response.ok) {
          const data = await response.json();
          if (data.success && data.diffraction_images) {
            this.diffractionImages = data.diffraction_images;

            // Find current image index
            this.currentImageIndex = this.diffractionImages.findIndex(img =>
              img.run_number === this.metadata.run_number &&
              img.image_number === this.metadata.image_number
            );

            if (this.currentImageIndex === -1) {
              this.currentImageIndex = 0;
            }

            console.log(`Loaded ${this.diffractionImages.length} diffraction images for navigation`);
          }
        }
      }
    } catch (error) {
      console.warn('Could not load diffraction images list for navigation:', error);
      // This is not critical - we can still view the single image
    }
  }

  async waitForVisualHeatmap() {
    return new Promise((resolve, reject) => {
      const checkLibrary = () => {
        // Check for different possible names the library might be available as
        if (window.Heatmap || window.visualHeatmap || window.VisualHeatmap) {
          console.log('Visual heatmap library found:', {
            Heatmap: !!window.Heatmap,
            visualHeatmap: !!window.visualHeatmap,
            VisualHeatmap: !!window.VisualHeatmap
          });
          resolve();
        } else if (document.readyState === 'complete') {
          console.error('Available window objects:', Object.keys(window).filter(k => k.toLowerCase().includes('heat')));
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
      console.log('SCXRD Viewer: Fetching raw diffraction data...');
      const response = await fetch(this.dataUrl);
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const responseData = await response.json();

      if (!responseData.success) {
        throw new Error(responseData.error || 'Failed to fetch diffraction data');
      }

      // Check if we got raw data (new format) or parsed data (fallback)
      if (responseData.raw_data) {
        console.log('SCXRD Viewer: Parsing raw ROD data client-side...');
        await this.parseRawData(responseData);
      } else if (responseData.image_data) {
        console.log('SCXRD Viewer: Using pre-parsed data...');
        this.processImageData(responseData.image_data, responseData.dimensions);
      } else {
        throw new Error('No valid image data found in response');
      }

      // Update metadata
      this.metadata = {
        ...this.metadata,
        ...responseData.metadata,
        dimensions: responseData.dimensions,
        pixel_size: responseData.pixel_size
      };

      // Calculate intensity statistics
      this.calculateIntensityRange();

      console.log(`Loaded ${this.currentData.length} data points for visualization`);
    } catch (error) {
      throw new Error(`Failed to load diffraction data: ${error.message}`);
    }
  }

  async parseRawData(responseData) {
    if (!window.RodImageParser) {
      throw new Error('ROD Image Parser not available. Please ensure rod_image_parser.js is loaded.');
    }

    console.log('SCXRD Viewer: Initializing client-side ROD parser...');

    // Show progress indicator for large files
    const fileSize = responseData.metadata?.file_size || 0;
    if (fileSize > 1024 * 1024) { // Show progress for files > 1MB
      this.showProgress('Parsing compressed data...', 0);
    }

    const parser = new RodImageParser(responseData.raw_data);

    console.log('SCXRD Viewer: Parsing compressed data...');
    const startTime = performance.now();

    // Parse data with progress updates
    const parsedData = await this.parseWithProgress(parser);

    const endTime = performance.now();
    const duration = (endTime - startTime).toFixed(1);

    console.log(`SCXRD Viewer: Client-side parsing completed in ${duration}ms`);

    if (fileSize > 1024 * 1024) {
      this.hideProgress();
    }

    if (!parsedData.success) {
      throw new Error(`Parsing failed: ${parsedData.error}`);
    }

    this.processImageData(parsedData.image_data, parsedData.dimensions);
  }

  async parseWithProgress(parser) {
    // For now, we'll just show indeterminate progress
    // In the future, we could modify the parser to report progress
    return new Promise((resolve) => {
      // Use setTimeout to allow UI updates
      setTimeout(async () => {
        try {
          const result = await parser.parse();
          resolve(result);
        } catch (error) {
          resolve({ success: false, error: error.message });
        }
      }, 10);
    });
  }

  showProgress(message, percentage = null) {
    const container = document.getElementById(this.containerId);
    if (!container) return;

    const heatmapContainer = container.querySelector(`#${this.containerId}_heatmap`);
    if (heatmapContainer) {
      const progressBar = percentage !== null ? `
        <div class="progress mt-3" style="width: 300px;">
          <div class="progress-bar" role="progressbar" style="width: ${percentage}%">
            ${percentage.toFixed(0)}%
          </div>
        </div>
      ` : '';

      heatmapContainer.innerHTML = `
        <div class="d-flex flex-column justify-content-center align-items-center h-100">
          <div class="text-center">
            <div class="spinner-border text-primary" role="status">
              <span class="visually-hidden">Loading...</span>
            </div>
            <div class="mt-2">${message}</div>
            ${progressBar}
          </div>
        </div>
      `;
    }
  }

  hideProgress() {
    // Progress will be hidden when visualization is created
  }

  processImageData(imageData, dimensions) {
    // Convert 1D array to 2D for visualization
    const [width, height] = dimensions;
    const data2D = [];

    for (let y = 0; y < height; y++) {
      const row = [];
      for (let x = 0; x < width; x++) {
        const index = y * width + x;
        row.push(imageData[index] || 0);
      }
      data2D.push(row);
    }

    // Convert 2D array to visual-heatmap format
    this.currentData = this.convertToHeatmapFormat(data2D);
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

    // Try to create visualization with fallback
    try {
      if (window.Heatmap) {
        this.createHeatmapVisualization(heatmapContainer);
      } else if (window.visualHeatmap) {
        this.createAlternativeVisualization(heatmapContainer);
      } else {
        this.createFallbackVisualization(heatmapContainer);
      }
      console.log('Visualization created successfully');
    } catch (error) {
      console.error('Failed to create visualization:', error);
      this.createFallbackVisualization(heatmapContainer);
    }
  }

  createHeatmapVisualization(container) {
    // Initialize visual-heatmap
    this.heatmapInstance = new window.Heatmap({
      container: container,
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
  }

  createAlternativeVisualization(container) {
    // Alternative visualization using available library
    console.log('Using alternative visualization method');
    this.createFallbackVisualization(container);
  }

  createFallbackVisualization(container) {
    // Simple fallback visualization showing data statistics
    const stats = this.calculateDataStatistics();

    container.innerHTML = `
      <div class="d-flex flex-column justify-content-center align-items-center h-100">
        <div class="card">
          <div class="card-header">
            <h5 class="mb-0">Diffraction Image Data (Fallback View)</h5>
          </div>
          <div class="card-body">
            <div class="row">
              <div class="col-md-6">
                <strong>Dimensions:</strong> ${this.metadata.dimensions ? this.metadata.dimensions.join(' × ') : 'Unknown'}
              </div>
              <div class="col-md-6">
                <strong>Data Points:</strong> ${stats.totalPoints.toLocaleString()}
              </div>
            </div>
            <div class="row mt-2">
              <div class="col-md-4">
                <strong>Min Intensity:</strong> ${stats.min}
              </div>
              <div class="col-md-4">
                <strong>Max Intensity:</strong> ${stats.max}
              </div>
              <div class="col-md-4">
                <strong>Mean Intensity:</strong> ${stats.mean.toFixed(2)}
              </div>
            </div>
            <div class="row mt-3">
              <div class="col-12">
                <div class="alert alert-info">
                  <strong>Note:</strong> Using fallback visualization. Full heatmap visualization requires the visual-heatmap library.
                  <br><small>Client-side parsing is working correctly with ${stats.totalPoints.toLocaleString()} pixels processed.</small>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    `;

    console.log('Fallback visualization created with data statistics:', stats);
  }

  calculateDataStatistics() {
    if (!this.currentData || this.currentData.length === 0) {
      return { totalPoints: 0, min: 0, max: 0, mean: 0 };
    }

    const values = this.currentData.map(point => point.value);
    const min = Math.min(...values);
    const max = Math.max(...values);
    const sum = values.reduce((a, b) => a + b, 0);
    const mean = sum / values.length;

    return {
      totalPoints: values.length,
      min: min,
      max: max,
      mean: mean
    };
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
            <div class="col-md-6">
              <button type="button" class="btn btn-secondary btn-sm me-2" id="${this.containerId}_reset">
                Reset View
              </button>
              <button type="button" class="btn btn-primary btn-sm me-2" id="${this.containerId}_export">
                Export Image
              </button>
            </div>
            <div class="col-md-6">
              ${this.diffractionImages.length > 1 ? `
                <div class="d-flex align-items-center justify-content-end">
                  <button type="button" class="btn btn-outline-primary btn-sm me-2" id="${this.containerId}_prev" 
                          ${this.currentImageIndex === 0 ? 'disabled' : ''}>
                    ‹ Previous
                  </button>
                  <span class="me-2">
                    <small class="text-muted">
                      ${this.currentImageIndex + 1} of ${this.diffractionImages.length}
                    </small>
                  </span>
                  <button type="button" class="btn btn-outline-primary btn-sm" id="${this.containerId}_next"
                          ${this.currentImageIndex === this.diffractionImages.length - 1 ? 'disabled' : ''}>
                    Next ›
                  </button>
                </div>
              ` : ''}
            </div>
          </div>
          <div class="row mt-2">
            <div class="col-md-12">
              <div class="d-inline-block">
                <small class="text-muted">
                  Data points: ${this.currentData ? this.currentData.length.toLocaleString() : 0}
                  ${this.metadata.dimensions ? ` | Size: ${this.metadata.dimensions}` : ''}
                  ${this.metadata.filename ? ` | File: ${this.metadata.filename}` : ''}
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
    const prevButton = document.getElementById(`${this.containerId}_prev`);
    const nextButton = document.getElementById(`${this.containerId}_next`);

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

    // Navigation buttons
    if (prevButton) {
      prevButton.addEventListener('click', () => this.navigateToPrevious());
    }

    if (nextButton) {
      nextButton.addEventListener('click', () => this.navigateToNext());
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

  // Navigation methods
  navigateToPrevious() {
    if (this.currentImageIndex > 0) {
      this.navigateToImage(this.currentImageIndex - 1);
    }
  }

  navigateToNext() {
    if (this.currentImageIndex < this.diffractionImages.length - 1) {
      this.navigateToImage(this.currentImageIndex + 1);
    }
  }

  async navigateToImage(index) {
    if (index < 0 || index >= this.diffractionImages.length) return;

    try {
      const imageInfo = this.diffractionImages[index];
      this.currentImageIndex = index;

      // Construct new URL for the selected image
      const newUrl = this.dataUrl.replace(/\/\d+\/image_data$/, `/${imageInfo.id}/image_data`);

      // Update metadata
      this.metadata = {
        ...this.metadata,
        run_number: imageInfo.run_number,
        image_number: imageInfo.image_number,
        filename: imageInfo.filename
      };

      console.log(`Navigating to image ${index + 1}/${this.diffractionImages.length}: ${imageInfo.display_name}`);

      // Show loading state
      const container = document.getElementById(this.containerId);
      if (container) {
        const heatmapContainer = container.querySelector(`#${this.containerId}_heatmap`);
        if (heatmapContainer) {
          heatmapContainer.innerHTML = `
            <div class="d-flex justify-content-center align-items-center h-100">
              <div class="text-center">
                <div class="spinner-border text-primary" role="status">
                  <span class="visually-hidden">Loading...</span>
                </div>
                <div class="mt-2">Loading ${imageInfo.display_name}...</div>
              </div>
            </div>
          `;
        }
      }

      // Clean up current data before loading new image
      this.cleanup();

      // Load new data
      this.dataUrl = newUrl;
      await this.loadData();

      // Recreate visualization
      this.createVisualization();

      // Update controls
      this.addControls();

      console.log(`Successfully loaded ${imageInfo.display_name}`);
    } catch (error) {
      console.error(`Failed to navigate to image ${index}:`, error);
      this.showError(`Failed to load image: ${error.message}`);
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

  cleanup() {
    // Clean up large data arrays to free memory
    if (this.currentData) {
      this.currentData.length = 0;
      this.currentData = null;
    }

    // Force garbage collection if available (Chrome DevTools)
    if (window.gc) {
      window.gc();
    }
  }

  destroy() {
    if (this.heatmapInstance && this.heatmapInstance.destroy) {
      this.heatmapInstance.destroy();
    }

    const container = document.getElementById(this.containerId);
    if (container) {
      container.innerHTML = '';
    }

    this.cleanup();

    this.heatmapInstance = null;
    this.diffractionImages = [];
    this.metadata = {};
  }
}

// Export for global use
window.ScxrdDiffractionViewer = ScxrdDiffractionViewer;