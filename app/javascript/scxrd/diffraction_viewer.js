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
    this.intensityScaleSet = false; // Track if intensity scale has been set from first image
    this.defaultIntensity = null; // Store the default intensity from first image
    this.maxSliderValue = null; // Store the max slider value from first image
    this.currentSliderValue = null; // Store the current slider value to prevent reset
    this.isPlaying = false; // Track if movie is playing
    this.playTimer = null; // Store the play timer
    this.playSpeed = 100; // Default play speed in milliseconds

    // Register with cleanup manager for Turbo navigation
    this.registerWithCleanupManager();
  }

  registerWithCleanupManager() {
    // Register this viewer instance for cleanup when navigating away
    if (window.turboCleanupManager) {
      // Add a custom cleanup method that will be called by the cleanup manager
      const cleanup = () => this.destroy();
      window.turboCleanupManager.registerCifVis({ destroy: cleanup });
    }
  }

  getVisualHeatmap() {
    // Try both possible property names
    return window.VisualHeatmap || window.visualHeatmap;
  }

  async loadImageData(wellId, datasetId, diffractionImageId = null) {


    // Reset intensity scale if we're loading a new dataset
    if (this.datasetId && this.datasetId !== datasetId) {
      console.log(`Switching from dataset ${this.datasetId} to ${datasetId} - resetting intensity scale`);
      this.resetIntensityScale();
    }

    // Store the current dataset and well IDs
    this.datasetId = datasetId;
    this.wellId = wellId;

    try {
      // Use different URL based on whether we're loading a specific diffraction image or the first/legacy image
      let url;
      if (diffractionImageId) {
        // Load specific diffraction image
        url = wellId && wellId !== 'null' && wellId !== null
          ? `/wells/${wellId}/scxrd_datasets/${datasetId}/diffraction_images/${diffractionImageId}/image_data`
          : `/scxrd_datasets/${datasetId}/diffraction_images/${diffractionImageId}/image_data`;
      } else {
        // Load first/legacy image (backward compatibility)
        url = wellId && wellId !== 'null' && wellId !== null
          ? `/wells/${wellId}/scxrd_datasets/${datasetId}/image_data`
          : `/scxrd_datasets/${datasetId}/image_data`;
      }

      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();


      if (!data.success) {
        throw new Error(data.error || 'Failed to load image data');
      }

      // Handle both old format (image_data array) and new format (raw_data base64)
      if (data.raw_data && !data.image_data) {


        // Parse raw data using client-side ROD parser
        if (window.RodImageParser) {
          try {
            const parser = new window.RodImageParser(data.raw_data);
            const parsedData = await parser.parse();
            if (parsedData.success) {

              // Use client-side results
              this.imageData = parsedData.image_data;
              this.dimensions = parsedData.dimensions;

            } else {
              throw new Error(`ROD parsing failed: ${parsedData.error}`);
            }
          } catch (error) {
            console.error('Client-side ROD parsing failed:', error);
            throw error;
          }
        } else {
          console.error('RodImageParser not available');
          throw new Error('RodImageParser not available for client-side parsing');
        }
      } else {
        // Use pre-parsed image data
        this.imageData = data.image_data;
      }

      this.dimensions = data.dimensions;
      this.metadata = data.metadata;
      this.currentDiffractionImageId = diffractionImageId;


      return true;
    } catch (error) {
      console.error('Error loading SCXRD image data:', error);
      this.showError(error.message);
      return false;
    }
  }



  async loadDiffractionImagesList(wellId, datasetId) {


    try {
      const url = wellId && wellId !== 'null' && wellId !== null
        ? `/wells/${wellId}/scxrd_datasets/${datasetId}/diffraction_images`
        : `/scxrd_datasets/${datasetId}/diffraction_images`;


      const response = await fetch(url, { headers: { 'Accept': 'application/json' } });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();


      if (!data.success) {
        throw new Error(data.error || 'Failed to load diffraction images');
      }

      this.diffractionImages = data.diffraction_images;
      this.availableRuns = data.runs;
      this.totalImagesCount = data.total_count;


      return true;
    } catch (error) {
      console.error('Error loading diffraction images list:', error);
      // If loading diffraction images fails, continue with legacy mode
      this.diffractionImages = [];
      this.availableRuns = [];
      this.totalImagesCount = 0;
      return false;
    }
  }

  getCurrentImageIndex() {
    if (!this.diffractionImages || !this.currentDiffractionImageId) return -1;
    return this.diffractionImages.findIndex(img => img.id === this.currentDiffractionImageId);
  }

  getNextImage() {
    const currentIndex = this.getCurrentImageIndex();
    if (currentIndex === -1 || currentIndex >= this.diffractionImages.length - 1) return null;
    return this.diffractionImages[currentIndex + 1];
  }

  getPreviousImage() {
    const currentIndex = this.getCurrentImageIndex();
    if (currentIndex <= 0) return null;
    return this.diffractionImages[currentIndex - 1];
  }

  async navigateToImage(diffractionImageId) {
    if (!diffractionImageId) return false;


    const success = await this.loadImageData(this.wellId, this.datasetId, diffractionImageId);
    if (success) {
      this.plotImage();
      this.updateNavigationControls();
    }
    return success;
  }

  async navigateNext() {
    const nextImage = this.getNextImage();
    if (nextImage) {
      return await this.navigateToImage(nextImage.id);
    }
    return false;
  }

  async navigatePrevious() {
    const previousImage = this.getPreviousImage();
    if (previousImage) {
      return await this.navigateToImage(previousImage.id);
    }
    return false;
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



    return heatmapData;
  }

  plotImage() {


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
        <div id="${this.containerId}-canvas" style="position: relative; width: 100%; flex: 1; border: 1px solid #dee2e6; overflow: hidden; background: #000;">
          <!-- Intensity slider overlay -->
          <div id="${this.containerId}-intensity-overlay" style="position: absolute; top: 10px; right: 10px; z-index: 10; background: rgba(0, 0, 0, 0.6); backdrop-filter: blur(4px); border-radius: 8px; padding: 8px 12px; display: flex; align-items: center; gap: 8px;">
            <label class="text-white fw-medium" style="font-size: 0.8rem; margin: 0;">Intensity:</label>
            <input type="range" id="${this.containerId}-intensity" class="form-range" 
                   style="width: 100px; height: 4px;" min="1" max="1000" value="100">
            <span id="${this.containerId}-intensity-value" class="text-white fw-medium" style="font-size: 0.8rem; min-width: 24px; text-align: center;">100</span>
          </div>
        </div>
        <div id="${this.containerId}-controls" style="height: 50px; padding: 5px; background: #f8f9fa; border-top: 1px solid #dee2e6; flex-shrink: 0;">
          <!-- Navigation controls will be added here -->
        </div>
      </div>
    `;

    const heatmapContainer = document.getElementById(`${this.containerId}-canvas`);

    // Create superpixel heatmap data
    const heatmapData = this.createSuperpixelHeatmapData();

    // Calculate intensity statistics for better scaling - only from first image
    let p99;
    let maxIntensity;
    if (!this.intensityScaleSet) {

      const sortedValues = this.imageData.filter(v => v > 0).sort((a, b) => a - b);
      maxIntensity = sortedValues[sortedValues.length - 1] || 1;
      p99 = sortedValues[Math.floor(sortedValues.length * 0.99)] || maxIntensity;

      this.currentIntensityRange = [0, p99];
      this.maxIntensity = maxIntensity; // Store for later use
      this.intensityScaleSet = true;

    } else {
      // Use the previously set intensity range
      p99 = this.currentIntensityRange[1];
      maxIntensity = this.maxIntensity || 1; // Use stored value
    }

    // Calculate scale factor to fit the card width
    const containerRect = heatmapContainer.getBoundingClientRect();
    const containerWidth = containerRect.width - 2; // Account for border
    const scaleFactor = Math.min(containerWidth / width, 1.0); // Don't scale up, only down

    // Apply scaling to coordinates while keeping top-left anchored
    const scaledHeatmapData = heatmapData.map(point => ({
      x: point.x * scaleFactor,
      y: point.y * scaleFactor,
      value: point.value
    }));

    // Create heatmap instance using Visual Heatmap API
    try {
      const HeatmapConstructor = this.getVisualHeatmap();



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
      }

      // Force a render/repaint
      if (typeof this.heatmapInstance.render === 'function') {
        this.heatmapInstance.render();
      } else if (typeof this.heatmapInstance.repaint === 'function') {
        this.heatmapInstance.repaint();
      }

      // Store the initial scale for zoom controls (no scaling now)
      this.initialScale = 1.0;

      // Calculate average pixel intensity and set default to 50x average - only from first image
      if (!this.defaultIntensity) {

        let totalIntensity = 0;
        let nonZeroPixels = 0;
        for (let i = 0; i < this.imageData.length; i++) {
          if (this.imageData[i] > 0) {
            totalIntensity += this.imageData[i];
            nonZeroPixels++;
          }
        }
        const averageIntensity = nonZeroPixels > 0 ? totalIntensity / nonZeroPixels : 100;
        this.averageIntensity = averageIntensity; // Store for later use
        this.defaultIntensity = averageIntensity * 50;
        this.maxSliderValue = this.defaultIntensity * 5;
      }

      this.addControls();

      // Trigger the slider event to apply the initial intensity (ensures consistent behavior)
      const intensitySlider = document.getElementById(`${this.containerId}-intensity`);
      if (intensitySlider) {
        const event = new Event('input', { bubbles: true });
        intensitySlider.dispatchEvent(event);

      }

      // Add window resize handler to rescale the diffraction image
      this.setupResizeHandler();



    } catch (error) {
      console.error('Error creating visual heatmap:', error);
      this.showError('Failed to create diffraction image visualization');
    }
  }

  addControls() {
    const controlsDiv = document.getElementById(`${this.containerId}-controls`);
    if (!controlsDiv) return;

    const [width, height] = this.dimensions;

    // Use the pre-calculated values from the first image
    const defaultValue = Math.round(this.defaultIntensity || 100);
    const maxValue = Math.round(this.maxSliderValue || 1000);

    // Use current slider value if available, otherwise use default
    const currentValue = this.currentSliderValue !== null ? this.currentSliderValue : defaultValue;

    // Build navigation controls if we have multiple diffraction images
    let navigationControls = '';
    if (this.totalImagesCount > 1) {
      const currentIndex = this.getCurrentImageIndex();
      const currentImage = this.diffractionImages[currentIndex];
      const imageInfo = currentImage ? `${currentImage.display_name}` : 'Legacy Image';

      navigationControls = `
        <div class="d-flex align-items-center me-3">
          <button id="${this.containerId}-prev" class="btn btn-outline-secondary me-1" style="width: 36px; height: 36px; padding: 0; display: flex; align-items: center; justify-content: center;" title="Previous frame" ${currentIndex <= 0 ? 'disabled' : ''}>
            <i class="bi bi-arrow-left-short" style="font-size: 16px;"></i>
          </button>
          <button id="${this.containerId}-play" class="btn btn-outline-primary me-1" style="width: 36px; height: 36px; padding: 0; display: flex; align-items: center; justify-content: center; transition: none;" title="Play/Pause sequence">
            <i class="bi bi-play-fill" style="font-size: 16px;"></i>
          </button>          
          <span class="mx-2 text-nowrap " style="font-size: 11px;">${imageInfo} (${currentIndex + 1}/${this.totalImagesCount})</span>
          <button id="${this.containerId}-next" class="btn btn-outline-secondary ms-1" style="width: 36px; height: 36px; padding: 0; display: flex; align-items: center; justify-content: center;" title="Next frame" ${currentIndex >= this.totalImagesCount - 1 ? 'disabled' : ''}>
            <i class="bi bi-arrow-right-short" style="font-size: 16px;"></i>
          </button>
        </div>
      `;
    }

    controlsDiv.innerHTML = `
      <div class="d-flex align-items-center justify-content-center">
        ${navigationControls}
      </div>
    `;

    // Update the intensity slider values in the overlay
    const intensitySlider = document.getElementById(`${this.containerId}-intensity`);
    const intensityValue = document.getElementById(`${this.containerId}-intensity-value`);

    if (intensitySlider && intensityValue) {
      intensitySlider.max = maxValue;
      intensitySlider.value = currentValue;
      intensityValue.textContent = currentValue;
    }

    // Add event listener for intensity control (elements already retrieved above)
    if (intensitySlider) {
      intensitySlider.addEventListener('input', (e) => {
        const sliderValue = parseInt(e.target.value);
        intensityValue.textContent = sliderValue;

        // Store the current slider value to prevent reset when changing images
        this.currentSliderValue = sliderValue;

        // Use the slider value directly as the intensity threshold (1-100)
        const newMax = sliderValue;
        this.currentIntensityRange[1] = newMax;

        // Update the heatmap's max value and re-render with defensive checks
        if (this.heatmapInstance && !this._destroyed) {
          try {
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
          } catch (error) {
            console.warn('Error updating heatmap intensity:', error);
            // If the heatmap instance is corrupted, mark as destroyed
            if (error.message && error.message.includes('null')) {
              this._destroyed = true;
            }
          }
        }
      });
    }

    // Add navigation event listeners
    const prevButton = document.getElementById(`${this.containerId}-prev`);
    const nextButton = document.getElementById(`${this.containerId}-next`);
    const playButton = document.getElementById(`${this.containerId}-play`);

    if (prevButton) {
      prevButton.addEventListener('click', async () => {
        // Stop playing when user manually navigates
        if (this.isPlaying) {
          this.stopPlay();
        }

        prevButton.disabled = true;
        await this.navigatePrevious();
        // Button state will be updated by updateNavigationControls
      });
    }

    if (nextButton) {
      nextButton.addEventListener('click', async () => {
        // Stop playing when user manually navigates
        if (this.isPlaying) {
          this.stopPlay();
        }

        nextButton.disabled = true;
        await this.navigateNext();
        // Button state will be updated by updateNavigationControls
      });
    }

    if (playButton) {
      playButton.addEventListener('click', () => {
        this.togglePlay();
      });
    }

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

  updateNavigationControls() {
    const prevButton = document.getElementById(`${this.containerId}-prev`);
    const nextButton = document.getElementById(`${this.containerId}-next`);
    const playButton = document.getElementById(`${this.containerId}-play`);

    if (prevButton && nextButton) {
      const currentIndex = this.getCurrentImageIndex();
      const currentImage = this.diffractionImages[currentIndex];

      prevButton.disabled = currentIndex <= 0;
      nextButton.disabled = currentIndex >= this.totalImagesCount - 1;

      // Disable play button if there's only one image
      if (playButton) {
        playButton.disabled = this.totalImagesCount <= 1;
      }

      // Update the image info display
      const imageInfo = currentImage ? `${currentImage.display_name}` : 'Legacy Image';
      const infoSpan = prevButton.parentElement.querySelector('.mx-2');
      if (infoSpan) {
        infoSpan.textContent = `${imageInfo} (${currentIndex + 1}/${this.totalImagesCount})`;
      }
    }

    // Update play button state to ensure correct icon is shown
    this.updatePlayButton();
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

    // Create a debounced resize handler with defensive checks
    let resizeTimeout;
    this.resizeHandler = () => {
      clearTimeout(resizeTimeout);
      resizeTimeout = setTimeout(() => {
        // Only resize if the viewer hasn't been destroyed
        if (this.containerId && document.getElementById(this.containerId)) {
          this.handleResize();
        }
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

  togglePlay() {
    if (this.isPlaying) {
      this.stopPlay();
    } else {
      this.startPlay();
    }
  }

  startPlay() {
    if (this.totalImagesCount <= 1) return; // Can't play with only one image

    this.isPlaying = true;
    this.updatePlayButton();

    // Start the play timer
    this.playTimer = setInterval(async () => {
      const currentIndex = this.getCurrentImageIndex();

      // If we're at the last image, loop back to the first
      if (currentIndex >= this.totalImagesCount - 1) {
        await this.navigateToImage(this.diffractionImages[0].id);
      } else {
        await this.navigateNext();
      }
    }, this.playSpeed);
  }

  stopPlay() {
    this.isPlaying = false;
    this.updatePlayButton();

    // Clear the play timer
    if (this.playTimer) {
      clearInterval(this.playTimer);
      this.playTimer = null;
    }
  }

  updatePlayButton() {
    const playButton = document.getElementById(`${this.containerId}-play`);
    if (playButton) {
      const icon = playButton.querySelector('i');
      if (this.isPlaying) {
        icon.className = 'bi bi-pause-fill';
        icon.style.fontSize = '16px';
        playButton.title = 'Pause sequence';
        playButton.classList.remove('btn-outline-primary');
        playButton.classList.add('btn-primary');
      } else {
        icon.className = 'bi bi-play-fill';
        icon.style.fontSize = '16px';
        playButton.title = 'Play sequence';
        playButton.classList.remove('btn-primary');
        playButton.classList.add('btn-outline-primary');
      }
    }
  }

  resetIntensityScale() {
    // Reset intensity scale to allow recalculation from next first image
    this.intensityScaleSet = false;
    this.defaultIntensity = null;
    this.maxSliderValue = null;
    this.maxIntensity = null;
    this.averageIntensity = null;
    this.currentSliderValue = null; // Reset slider value when switching datasets
    this.currentIntensityRange = [0, 1000];

  }

  destroy() {
    console.log(`Destroying SCXRD diffraction viewer: ${this.containerId}`);
    
    // Stop playing and clean up timer
    if (this.isPlaying) {
      this.stopPlay();
    }

    // Clean up resize handler when viewer is destroyed
    if (this.resizeHandler) {
      window.removeEventListener('resize', this.resizeHandler);
      this.resizeHandler = null;
    }

    // Clean up heatmap instance
    if (this.heatmapInstance) {
      try {
        if (typeof this.heatmapInstance.destroy === 'function') {
          this.heatmapInstance.destroy();
        } else if (typeof this.heatmapInstance.clear === 'function') {
          this.heatmapInstance.clear();
        }
      } catch (error) {
        console.warn('Error destroying heatmap instance:', error);
      }
      this.heatmapInstance = null;
    }

    // Clear the container
    const container = document.getElementById(this.containerId);
    if (container) {
      container.innerHTML = '';
    }

    // Clean up global reference
    const globalRef = `scxrdViewer_${this.containerId.replace('-', '_')}`;
    if (window[globalRef]) {
      delete window[globalRef];
    }

    // Reset all instance variables
    this.plotDiv = null;
    this.imageData = null;
    this.dimensions = null;
    this.metadata = null;
    this.diffractionImages = null;
    this.availableRuns = null;
    this.currentDiffractionImageId = null;
  }
}

// Make available globally
window.ScxrdDiffractionViewer = ScxrdDiffractionViewer;
console.log('ScxrdDiffractionViewer (Visual Heatmap) defined');