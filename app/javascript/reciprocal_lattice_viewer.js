// SCXRD Reciprocal Lattice Viewer using Three.js ES modules
// Translates the Python visualization from scripts/rlatt.py to JavaScript

// Import Three.js ES modules
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
        this.pointSize = 0.02;
        this.colorScale = 'viridis';
        this.intensityRange = [0, 100];
        this.currentAxisColors = { x: 'red', y: 'green', z: 'blue' };

        // Animation and interaction
        this.animationId = null;
        this.isAnimating = false;

        // Three.js is now available via ES modules
        this.threeAvailable = true;
        this.THREE = THREE;
    }

    checkThreeJsAvailability() {
        if (typeof THREE !== 'undefined') {
            this.threeAvailable = true;
            console.log('Three.js is available');
        } else {
            console.log('Three.js not found, attempting to load...');
            this.loadThreeJs();
        }
    }

    loadThreeJs() {
        // Suppress the Multiple instances warning by temporarily removing __THREE__
        const previousTHREE = window.__THREE__;
        delete window.__THREE__;

        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/three@0.159.0/build/three.min.js';
        script.onload = () => {
            console.log('Three.js loaded successfully');
            this.threeAvailable = true;

            // Restore previous __THREE__ if it existed (for CifVis)
            if (previousTHREE) {
                window.__THREE__ = previousTHREE;
            }

            this.loadOrbitControls();
        };
        script.onerror = () => {
            console.error('Failed to load Three.js');

            // Restore previous __THREE__ if it existed (for CifVis)
            if (previousTHREE) {
                window.__THREE__ = previousTHREE;
            }

            this.showError('Failed to load 3D visualization library');
        };
        document.head.appendChild(script);
    }

    loadOrbitControls() {
        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/three@0.159.0/examples/js/controls/OrbitControls.js';
        script.onload = () => {
            console.log('OrbitControls loaded successfully');
        };
        script.onerror = () => {
            console.warn('Failed to load OrbitControls, will use basic mouse controls');
        };
        document.head.appendChild(script);
    }

    async loadPeakTableData(wellId, datasetId) {
        console.log(`Loading reciprocal lattice data for well ${wellId}, dataset ${datasetId}`);

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
        console.log('plotReciprocalLattice() called');

        if (!this.threeAvailable) {
            this.showError('3D visualization library not available. Please ensure Three.js is loaded.');
            return;
        }

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

        // Create container structure
        this.container.innerHTML = `
      <div style="position: relative; width: 100%; height: 100%; display: flex; flex-direction: column;">
        <div id="${this.containerId}-canvas" style="width: 100%; flex: 1; border: 1px solid #dee2e6; overflow: hidden; background: #000;"></div>
        <div id="${this.containerId}-controls" style="height: 60px; padding: 8px; background: #f8f9fa; border-top: 1px solid #dee2e6; flex-shrink: 0;">
          <!-- Controls will be added here -->
        </div>
      </div>
    `;

        const canvasContainer = document.getElementById(`${this.containerId}-canvas`);
        const containerRect = canvasContainer.getBoundingClientRect();

        // Initialize Three.js scene
        this.scene = new THREE.Scene();
        this.scene.background = new THREE.Color(0x000011);

        // Setup camera
        this.camera = new THREE.PerspectiveCamera(
            75,
            containerRect.width / containerRect.height,
            0.1,
            1000
        );

        // Setup renderer
        this.renderer = new THREE.WebGLRenderer({ antialias: true });
        this.renderer.setSize(containerRect.width, containerRect.height);
        this.renderer.setPixelRatio(window.devicePixelRatio);
        canvasContainer.appendChild(this.renderer.domElement);

        // Setup camera controls if available
        if (typeof THREE.OrbitControls !== 'undefined') {
            this.controls = new THREE.OrbitControls(this.camera, this.renderer.domElement);
            this.controls.enableDamping = true;
            this.controls.dampingFactor = 0.05;
        }

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
        const axesHelper = new THREE.AxesHelper(2);
        axesHelper.setColors(
            new THREE.Color(0xff0000), // X - Red
            new THREE.Color(0x00ff00), // Y - Green  
            new THREE.Color(0x0000ff)  // Z - Blue
        );
        this.scene.add(axesHelper);

        // Add axis labels
        this.addAxisLabels();
    }

    addAxisLabels() {
        // Create simple text sprites for axis labels
        const loader = new THREE.FontLoader();

        // For now, just add colored spheres at axis endpoints as labels
        const labelGeometry = new THREE.SphereGeometry(0.03, 8, 8);

        // X axis label (red)
        const xLabelMaterial = new THREE.MeshBasicMaterial({ color: 0xff0000 });
        const xLabel = new THREE.Mesh(labelGeometry, xLabelMaterial);
        xLabel.position.set(2.2, 0, 0);
        this.scene.add(xLabel);

        // Y axis label (green)
        const yLabelMaterial = new THREE.MeshBasicMaterial({ color: 0x00ff00 });
        const yLabel = new THREE.Mesh(labelGeometry, yLabelMaterial);
        yLabel.position.set(0, 2.2, 0);
        this.scene.add(yLabel);

        // Z axis label (blue)
        const zLabelMaterial = new THREE.MeshBasicMaterial({ color: 0x0000ff });
        const zLabel = new THREE.Mesh(labelGeometry, zLabelMaterial);
        zLabel.position.set(0, 0, 2.2);
        this.scene.add(zLabel);
    }

    createPointCloud() {
        // Calculate data range for normalization
        const rValues = this.dataPoints.map(p => p.r);
        const rMin = Math.min(...rValues);
        const rMax = Math.max(...rValues);

        console.log(`R value range: ${rMin} to ${rMax}`);

        // Create geometry and materials
        const geometry = new THREE.BufferGeometry();
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

        geometry.setAttribute('position', new THREE.Float32BufferAttribute(positions, 3));
        geometry.setAttribute('color', new THREE.Float32BufferAttribute(colors, 3));

        // Create point material
        const material = new THREE.PointsMaterial({
            size: this.pointSize,
            vertexColors: true,
            transparent: true,
            opacity: 0.8,
            sizeAttenuation: true
        });

        // Create points mesh
        this.points = new THREE.Points(geometry, material);
        this.scene.add(this.points);

        console.log(`Created point cloud with ${positions.length / 3} points`);
    }

    getColorFromValue(normalizedValue) {
        // Simple viridis-like color mapping
        const r = Math.max(0, Math.min(1, 2 * normalizedValue - 1));
        const g = Math.max(0, Math.min(1, normalizedValue < 0.5 ? 2 * normalizedValue : 2 * (1 - normalizedValue)));
        const b = Math.max(0, Math.min(1, 1 - 2 * normalizedValue));

        return { r, g, b };
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
          <label class="me-2">Point Size:</label>
          <input type="range" id="${this.containerId}-size" class="form-range" 
                 style="width: 80px;" min="0.005" max="0.1" step="0.005" value="${this.pointSize}">
          <span id="${this.containerId}-size-value" class="ms-1">${this.pointSize}</span>
        </div>
        <div class="d-flex align-items-center">
          <label class="me-2">Intensity Range:</label>
          <input type="range" id="${this.containerId}-intensity-min" class="form-range" 
                 style="width: 80px;" min="${rMin}" max="${rMax}" value="${rMin}">
          <span class="mx-1">-</span>
          <input type="range" id="${this.containerId}-intensity-max" class="form-range" 
                 style="width: 80px;" min="${rMin}" max="${rMax}" value="${rMax}">
        </div>
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
        // Point size control
        const sizeSlider = document.getElementById(`${this.containerId}-size`);
        const sizeValue = document.getElementById(`${this.containerId}-size-value`);

        if (sizeSlider && sizeValue) {
            sizeSlider.addEventListener('input', (e) => {
                this.pointSize = parseFloat(e.target.value);
                sizeValue.textContent = this.pointSize.toFixed(3);
                if (this.points) {
                    this.points.material.size = this.pointSize;
                }
            });
        }

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

        // Intensity range controls
        const intensityMinSlider = document.getElementById(`${this.containerId}-intensity-min`);
        const intensityMaxSlider = document.getElementById(`${this.containerId}-intensity-max`);

        if (intensityMinSlider && intensityMaxSlider) {
            const updateIntensityFilter = () => {
                const minVal = parseFloat(intensityMinSlider.value);
                const maxVal = parseFloat(intensityMaxSlider.value);
                this.intensityRange = [minVal, maxVal];
                this.updatePointVisibility();
            };

            intensityMinSlider.addEventListener('input', updateIntensityFilter);
            intensityMaxSlider.addEventListener('input', updateIntensityFilter);
        }
    }

    updatePointVisibility() {
        if (!this.points) return;

        const positions = this.points.geometry.attributes.position.array;
        const colors = this.points.geometry.attributes.color.array;

        // Update colors based on intensity filter
        this.dataPoints.forEach((point, index) => {
            const inRange = point.r >= this.intensityRange[0] && point.r <= this.intensityRange[1];
            const baseIndex = index * 3;

            if (inRange) {
                // Show point with normal color
                const rValues = this.dataPoints.map(p => p.r);
                const rMin = Math.min(...rValues);
                const rMax = Math.max(...rValues);
                const normalizedR = (point.r - rMin) / (rMax - rMin);
                const color = this.getColorFromValue(normalizedR);

                colors[baseIndex] = color.r;
                colors[baseIndex + 1] = color.g;
                colors[baseIndex + 2] = color.b;
            } else {
                // Hide point by making it transparent/dark
                colors[baseIndex] = 0.1;
                colors[baseIndex + 1] = 0.1;
                colors[baseIndex + 2] = 0.1;
            }
        });

        this.points.geometry.attributes.color.needsUpdate = true;
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
                if (width > 0 && height > 0) {
                    this.camera.aspect = width / height;
                    this.camera.updateProjectionMatrix();
                    this.renderer.setSize(width, height);
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

// Make available globally
window.ScxrdReciprocalLatticeViewer = ScxrdReciprocalLatticeViewer;
console.log('ScxrdReciprocalLatticeViewer defined');