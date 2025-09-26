// Import Three.js directly
import * as THREE from 'three';

class ScxrdReciprocalLatticeViewer {
  constructor(containerId) {
    this.containerId = containerId;
    this.container = null;
    this.scene = null;
    this.camera = null;
    this.renderer = null;
    this.controls = null;
    this.points = null;
    this.dataPoints = [];
    this.statistics = {};

    // Material and visualization settings
    this.pointSize = 2;
    this.intensityRange = [0, 100];

    // Animation and interaction
    this.animationId = null;
    this.isAnimating = false;

    // Three.js is now directly imported
    this.THREE = THREE;
    this.threeAvailable = true;

    // Make Three.js globally available for CifVis compatibility
    window.THREE = THREE;

    console.log('ScxrdReciprocalLatticeViewer initialized with imported Three.js');
  }

  

  waitForThreeJs() {
    const checkInterval = setInterval(() => {
      console.log('Waiting for Three.js, checking:', {
        'window.__THREE__': typeof window.__THREE__,
        'window.THREE': typeof window.THREE,
        '__THREE__ has Scene': window.__THREE__ && typeof window.__THREE__.Scene,
        'THREE has Scene': window.THREE && typeof window.THREE.Scene
      });
      
      if ((window.__THREE__ && typeof window.__THREE__.Scene === 'function') || 
          (window.THREE && typeof window.THREE.Scene === 'function')) {
        this.THREE = (window.__THREE__ && typeof window.__THREE__.Scene === 'function') ? window.__THREE__ : window.THREE;
        this.threeAvailable = true;
        console.log('Three.js now available, type:', typeof this.THREE, 'Scene constructor:', typeof this.THREE.Scene);
        clearInterval(checkInterval);
        
        // Trigger any pending operations that were waiting for Three.js
        if (this.pendingOperation) {
          this.pendingOperation();
          this.pendingOperation = null;
        }
      }
    }, 100);

    // Timeout after 10 seconds
    setTimeout(() => {
      if (!this.threeAvailable) {
        clearInterval(checkInterval);
        console.error('Three.js failed to load within 10 seconds');
      }
    }, 10000);
  }

  // Three.js is now loaded via ES modules - no dynamic loading needed

  async loadPeakTableData(wellId, datasetId) {
    console.log(`Loading reciprocal lattice data for well ${wellId}, dataset ${datasetId}`);

    // Store these for fallback use
    this.wellId = wellId;
    this.datasetId = datasetId;

    try {
      const url = `/wells/${wellId}/scxrd_datasets/${datasetId}/peak_table_data`;
      console.log(`Fetching from: ${url}`);
      const response = await fetch(url);

      console.log(`Response status: ${response.status}`);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      console.log('Received data:', {
        success: data.success,
        dataPointsLength: data.data_points?.length,
        statistics: data.statistics
      });

      if (!data.success) {
        throw new Error(data.error || 'Failed to load peak table data');
      }

      this.dataPoints = data.data_points;
      this.statistics = data.statistics;

      console.log(`Loaded ${this.dataPoints.length} reciprocal lattice points`);
      return true;
    } catch (error) {
      console.error('Error loading reciprocal lattice data:', error);
      this.showError(error.message);
      return false;
    }
  }

  plotReciprocalLattice() {
    console.log('plotReciprocalLattice() called with imported Three.js');

    this.container = document.getElementById(this.containerId);
    if (!this.container) {
      console.error(`Container '${this.containerId}' not found`);
      return;
    }

    if (!this.dataPoints || this.dataPoints.length === 0) {
      this.showError('No reciprocal lattice data available');
      return;
    }

    console.log(`Setting up 3D visualization with ${this.dataPoints.length} points`);

    // Clear existing content
    this.container.innerHTML = '';

    // Create container structure with explicit full width
    this.container.innerHTML = `
      <div style="position: relative; width: 100%; height: 100%; display: flex; flex-direction: column; box-sizing: border-box;">
        <div id="${this.containerId}-canvas" style="width: 100%; flex: 1 1 auto; overflow: hidden; background: #000; min-height: 0; box-sizing: border-box;"></div>
        <div id="${this.containerId}-controls" style="height: 50px; padding: 8px; background: #f8f9fa; border-top: 1px solid #dee2e6; flex-shrink: 0; width: 100%; box-sizing: border-box;">
          <!-- Controls will be added here -->
        </div>
      </div>
    `;

    const canvasContainer = document.getElementById(`${this.containerId}-canvas`);

    // Force container to take full width
    canvasContainer.style.width = '100%';
    canvasContainer.style.height = '100%';

    // Wait a moment for layout to settle, then get dimensions
    setTimeout(() => {
      const containerRect = canvasContainer.getBoundingClientRect();
      console.log(`Canvas container dimensions: ${containerRect.width}x${containerRect.height}`);

      // Initialize Three.js scene
      this.scene = new this.THREE.Scene();
      this.scene.background = new this.THREE.Color(0x000011);

      // Setup orthographic camera for technical/scientific visualization
      const aspect = containerRect.width / containerRect.height;
      const frustumSize = 5;
      this.camera = new this.THREE.OrthographicCamera(
        frustumSize * aspect / -2,
        frustumSize * aspect / 2,
        frustumSize / 2,
        frustumSize / -2,
        0.1,
        1000
      );

      // Set default zoom level to 10
      this.camera.zoom = 10;
      this.camera.updateProjectionMatrix();

      // Setup renderer
      this.renderer = new this.THREE.WebGLRenderer({ antialias: true });
      this.renderer.setSize(containerRect.width, containerRect.height);
      this.renderer.setPixelRatio(window.devicePixelRatio);

      // Add renderer to container
      canvasContainer.appendChild(this.renderer.domElement);

      this.continueSetup();
    }, 50);
  }

  continueSetup() {
    // Setup basic mouse controls for camera interaction
    console.log('Using basic mouse interaction for reciprocal lattice viewer');
    this.addBasicMouseControls();

    // Add coordinate axes
    this.addAxes();

    // Create point cloud from reciprocal lattice data
    this.createPointCloud();

    // Position camera
    this.positionCamera();

    // Add controls
    this.addControls();

    // Start animation loop
    this.startAnimation();

    // Handle window resize
    this.setupResizeHandler();

    console.log('3D reciprocal lattice visualization created successfully');
  }

  addAxes() {
    const axesHelper = new this.THREE.AxesHelper(2);
    this.scene.add(axesHelper);
  }

  addBasicMouseControls() {
    // Basic mouse rotation controls as fallback
    let isDragging = false;
    let previousMousePosition = { x: 0, y: 0 };

    this.renderer.domElement.addEventListener('mousedown', (e) => {
      isDragging = true;
      previousMousePosition = { x: e.clientX, y: e.clientY };
    });

    this.renderer.domElement.addEventListener('mousemove', (e) => {
      if (!isDragging) return;

      const deltaMove = {
        x: e.clientX - previousMousePosition.x,
        y: e.clientY - previousMousePosition.y
      };

      // Rotate camera around the center
      const spherical = new this.THREE.Spherical();
      spherical.setFromVector3(this.camera.position);

      spherical.theta -= deltaMove.x * 0.01;
      spherical.phi += deltaMove.y * 0.01;
      spherical.phi = Math.max(0.1, Math.min(Math.PI - 0.1, spherical.phi));

      this.camera.position.setFromSpherical(spherical);
      this.camera.lookAt(0, 0, 0);

      previousMousePosition = { x: e.clientX, y: e.clientY };
    });

    this.renderer.domElement.addEventListener('mouseup', () => {
      isDragging = false;
    });

    // Mouse wheel for zoom - adjust orthographic camera zoom
    this.renderer.domElement.addEventListener('wheel', (e) => {
      e.preventDefault();
      const scale = e.deltaY > 0 ? 1.1 : 0.9;

      // For orthographic camera, adjust the frustum size instead of position
      const aspect = this.renderer.domElement.width / this.renderer.domElement.height;
      let frustumSize = (this.camera.right - this.camera.left) / aspect;
      frustumSize *= scale;

      // Limit zoom
      frustumSize = Math.max(0.5, Math.min(20, frustumSize));

      this.camera.left = frustumSize * aspect / -2;
      this.camera.right = frustumSize * aspect / 2;
      this.camera.top = frustumSize / 2;
      this.camera.bottom = frustumSize / -2;
      this.camera.updateProjectionMatrix();
    });

    console.log('Basic mouse controls added');
  }

  createPointCloud() {
    // Calculate data range for normalization
    const rValues = this.dataPoints.map(p => p.r);
    const rMin = Math.min(...rValues);
    const rMax = Math.max(...rValues);

    console.log(`R value range: ${rMin} to ${rMax}`);

    // Create geometry and materials
    const geometry = new this.THREE.BufferGeometry();
    const positions = [];
    const colors = [];

    // Convert data points to Three.js format
    this.dataPoints.forEach(point => {
      // Add position (scaling down for better visualization)
      positions.push(point.x * 0.1, point.y * 0.1, point.z * 0.1);

      // Add color based on r value (intensity)
      const normalizedR = (point.r - rMin) / (rMax - rMin);
      const color = this.getColorFromValue(normalizedR);
      colors.push(color.r, color.g, color.b);
    });

    geometry.setAttribute('position', new this.THREE.Float32BufferAttribute(positions, 3));
    geometry.setAttribute('color', new this.THREE.Float32BufferAttribute(colors, 3));

    // Create point material
    const material = new this.THREE.PointsMaterial({
      size: this.pointSize,
      vertexColors: true,
      transparent: true,
      opacity: 0.8,
      sizeAttenuation: true
    });

    // Create points mesh
    this.points = new this.THREE.Points(geometry, material);
    this.scene.add(this.points);

    console.log(`Created point cloud with ${positions.length / 3} points`);
  }

  getColorFromValue(normalizedValue) {
    // Light blue color for all points
    return { r: 0.5, g: 0.8, b: 1.0 };
  }

  positionCamera() {
    // Position camera for good view of the data
    if (this.statistics.x && this.statistics.y && this.statistics.z) {
      const centerX = this.statistics.x.mean * 0.1;
      const centerY = this.statistics.y.mean * 0.1;
      const centerZ = this.statistics.z.mean * 0.1;

      this.camera.position.set(centerX + 2, centerY + 2, centerZ + 2);
      this.camera.lookAt(centerX, centerY, centerZ);

      if (this.controls) {
        this.controls.target.set(centerX, centerY, centerZ);
      }
    } else {
      this.camera.position.set(2, 2, 2);
      this.camera.lookAt(0, 0, 0);
    }
  }

  addControls() {
    const controlsDiv = document.getElementById(`${this.containerId}-controls`);
    if (!controlsDiv) return;

    // Calculate initial intensity range
    const rValues = this.dataPoints.map(p => p.r);
    const rMin = Math.min(...rValues);
    const rMax = Math.max(...rValues);

    controlsDiv.innerHTML = `
      <div class="d-flex align-items-center justify-content-center gap-3" style="font-size: 0.8rem;">
        <div class="d-flex align-items-center">
          <button id="${this.containerId}-reset" class="btn btn-sm btn-outline-primary">Reset View</button>
        </div>
        <div class="d-flex align-items-center">
          <span class="small text-muted">${this.dataPoints.length} points</span>
        </div>
      </div>
    `;

    // Add event listeners
    this.setupControlEventListeners();
  }

  setupControlEventListeners() {
    // Reset view button
    const resetButton = document.getElementById(`${this.containerId}-reset`);
    if (resetButton) {
      resetButton.addEventListener('click', () => {
        this.positionCamera();
        if (this.controls) {
          this.controls.reset();
        }
      });
    }
  }

  startAnimation() {
    this.isAnimating = true;
    this.animate();
  }

  animate() {
    if (!this.isAnimating) return;

    this.animationId = requestAnimationFrame(() => this.animate());

    // Update controls
    if (this.controls) {
      this.controls.update();
    }

    // Render scene
    this.renderer.render(this.scene, this.camera);
  }

  setupResizeHandler() {
    const resizeObserver = new ResizeObserver(entries => {
      for (let entry of entries) {
        const { width, height } = entry.contentRect;
        console.log(`Canvas resize detected: ${width}x${height}`);
        if (width > 0 && height > 0) {
          // Update orthographic camera frustum
          const aspect = width / height;
          const frustumSize = 5;
          this.camera.left = frustumSize * aspect / -2;
          this.camera.right = frustumSize * aspect / 2;
          this.camera.top = frustumSize / 2;
          this.camera.bottom = frustumSize / -2;
          this.camera.updateProjectionMatrix();
          this.renderer.setSize(width, height);

          // Ensure canvas style matches
          this.renderer.domElement.style.width = '100%';
          this.renderer.domElement.style.height = '100%';
        }
      }
    });

    const canvasContainer = document.getElementById(`${this.containerId}-canvas`);
    if (canvasContainer) {
      resizeObserver.observe(canvasContainer);
    }
  }

  showError(message) {
    const container = document.getElementById(this.containerId);
    if (container) {
      container.innerHTML = `
        <div class="alert alert-danger m-3" role="alert">
          <h6>Error Loading Reciprocal Lattice</h6>
          <p class="mb-0">${message}</p>
        </div>
      `;
    }
  }

  showLoading() {
    const container = document.getElementById(this.containerId);
    if (container) {
      container.innerHTML = `
        <div class="d-flex justify-content-center align-items-center" style="height: 30vw;">
          <div class="text-center">
            <div class="spinner-border text-primary" role="status">
              <span class="visually-hidden">Loading...</span>
            </div>
            <div class="mt-2">Loading reciprocal lattice...</div>
          </div>
        </div>
      `;
    }
  }

  showFallbackVisualization() {
    console.log('Showing fallback visualization');
    const container = document.getElementById(this.containerId);
    if (!container) return;

    // Show a simple 2D projection of the data as fallback
    const stats = this.statistics;
    const pointCount = this.dataPoints.length;

    container.innerHTML = `
      <div class="p-3">
        <div class="alert alert-warning mb-3">
          <h6><i class="fas fa-exclamation-triangle me-2"></i>3D Viewer Unavailable</h6>
          <p class="mb-0">Showing data summary instead. The 3D visualization requires Three.js library.</p>
        </div>
        
        <div class="row">
          <div class="col-md-6">
            <h6>Reciprocal Lattice Data</h6>
            <ul class="list-unstyled">
              <li><strong>Points:</strong> ${pointCount.toLocaleString()}</li>
              ${stats.x ? `<li><strong>X Range:</strong> ${stats.x.min.toFixed(3)} to ${stats.x.max.toFixed(3)}</li>` : ''}
              ${stats.y ? `<li><strong>Y Range:</strong> ${stats.y.min.toFixed(3)} to ${stats.y.max.toFixed(3)}</li>` : ''}
              ${stats.z ? `<li><strong>Z Range:</strong> ${stats.z.min.toFixed(3)} to ${stats.z.max.toFixed(3)}</li>` : ''}
              ${stats.r ? `<li><strong>Intensity Range:</strong> ${stats.r.min.toFixed(3)} to ${stats.r.max.toFixed(3)}</li>` : ''}
            </ul>
          </div>
          <div class="col-md-6">
            <h6>Actions</h6>
            <a href="/wells/${this.wellId}/scxrd_datasets/${this.datasetId}/download_peak_table" 
               class="btn btn-success btn-sm">
              <i class="fas fa-download me-1"></i>Download Peak Table
            </a>
            <button class="btn btn-outline-primary btn-sm ms-2" onclick="location.reload()">
              <i class="fas fa-redo me-1"></i>Retry 3D View
            </button>
          </div>
        </div>
      </div>
    `;
  }

  destroy() {
    // Stop animation
    this.isAnimating = false;
    if (this.animationId) {
      cancelAnimationFrame(this.animationId);
    }

    // Dispose of Three.js objects
    if (this.points) {
      this.points.geometry.dispose();
      this.points.material.dispose();
    }

    if (this.renderer) {
      this.renderer.dispose();
    }

    // Clear container
    const container = document.getElementById(this.containerId);
    if (container) {
      container.innerHTML = '';
    }
  }
}

// Export the class and make it globally available
export { ScxrdReciprocalLatticeViewer };
window.ScxrdReciprocalLatticeViewer = ScxrdReciprocalLatticeViewer;
console.log('ScxrdReciprocalLatticeViewer defined with imported Three.js');