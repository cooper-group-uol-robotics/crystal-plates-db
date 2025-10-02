// Inline Reciprocal Lattice Viewer Class
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

    // Orbit navigation with quaternions (initialized after Three.js loads)
    this.orbitControls = {
      enabled: true,
      target: null, // Will be initialized as THREE.Vector3 when Three.js loads
      minDistance: 1,
      maxDistance: 50,
      minPolarAngle: -Infinity, // Allow full rotation over Y axis
      maxPolarAngle: Infinity,  // Allow full rotation over Y axis
      enableDamping: true,
      dampingFactor: 0.2, // Moderate damping for natural feel
      enableZoom: true,
      zoomSpeed: 3, // Increased zoom sensitivity
      enableRotate: true,
      rotateSpeed: 0.5, // Further reduced rotation sensitivity for smoothness
      enablePan: true,
      panSpeed: 0.5, // Reduced pan sensitivity
      autoRotate: false,
      autoRotateSpeed: 2.0
    };

    // Mouse interaction state (initialized after Three.js loads)
    this.mouseState = {
      isDown: false,
      button: -1,
      startPosition: null, // Will be initialized as THREE.Vector2
      currentPosition: null, // Will be initialized as THREE.Vector2
      deltaPosition: null // Will be initialized as THREE.Vector2
    };

    // Camera state for CifVis-style navigation (initialized after Three.js loads)
    this.cameraState = {
      position: null, // Will be initialized as THREE.Vector3 for camera position
      positionStart: null, // Starting position for drag operations
      scale: 1,
      panOffset: null, // Will be initialized as THREE.Vector3
      zoomChanged: false
    };

    // Three.js availability check
    this.threeAvailable = false;
    this.checkThreeJsAvailability();
  }

  checkThreeJsAvailability() {
    if (typeof THREE !== 'undefined') {
      this.threeAvailable = true;
      console.log('Three.js is already available');
    } else if (window.threeJsLoading) {
      console.log('Three.js is already being loaded by another instance, waiting...');
      // Wait for the global loading to complete
    } else {
      console.log('Three.js not found, loading from CDN...');
      window.threeJsLoading = true; // Mark as loading globally
      this.loadThreeJs();

      // Set a timeout for loading Three.js
      setTimeout(() => {
        if (!this.threeAvailable && typeof THREE === 'undefined') {
          console.warn('Three.js loading timed out after 15 seconds, will use fallback visualization');
          window.threeJsLoading = false; // Reset loading flag
        }
      }, 15000); // 15 second timeout
    }
  }

  loadThreeJs() {
    // Use traditional script loading approach with better CDN selection
    console.log('Loading Three.js using traditional script approach...');

    // Suppress the Multiple instances warning by temporarily removing __THREE__
    const previousTHREE = window.__THREE__;
    delete window.__THREE__;

    // Use CDN that serves the current Three.js global build
    const threeScript = document.createElement('script');
    threeScript.src = 'https://cdnjs.cloudflare.com/ajax/libs/three.js/0.160.1/three.min.js';
    threeScript.onload = () => {
      console.log('Three.js loaded successfully for reciprocal lattice viewer');
      this.threeAvailable = true;
      window.threeJsLoading = false; // Reset loading flag
      window.threeJsLoaded = true; // Mark as globally loaded

      // Restore previous __THREE__ if it existed (for CifVis)
      if (previousTHREE) {
        window.__THREE__ = previousTHREE;
      }

      // Notify that Three.js is ready
      window.dispatchEvent(new CustomEvent('threeJsLoaded'));
    };

    threeScript.onerror = () => {
      console.error('Failed to load Three.js, trying fallback...');

      // Fallback to jsdelivr with alternative URL
      const fallbackScript = document.createElement('script');
      fallbackScript.src = 'https://cdn.jsdelivr.net/npm/three@0.160.1/build/three.min.js';
      fallbackScript.onload = () => {
        console.log('Three.js loaded from fallback');
        this.threeAvailable = true;
        window.threeJsLoading = false; // Reset loading flag
        window.threeJsLoaded = true; // Mark as globally loaded

        // Restore previous __THREE__ if it existed (for CifVis)
        if (previousTHREE) {
          window.__THREE__ = previousTHREE;
        }

        window.dispatchEvent(new CustomEvent('threeJsLoaded'));
      };
      fallbackScript.onerror = () => {
        console.error('All Three.js loading attempts failed');
        window.threeJsLoading = false; // Reset loading flag

        // Restore previous __THREE__ if it existed (for CifVis)
        if (previousTHREE) {
          window.__THREE__ = previousTHREE;
        }
      };
      document.head.appendChild(fallbackScript);
    };

    document.head.appendChild(threeScript);

    // Listen for the Three.js loaded event
    window.addEventListener('threeJsLoaded', () => {
      this.threeAvailable = true;
      console.log('Three.js is ready for use');
    }, { once: true });
  }

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
    console.log('plotReciprocalLattice() called');

    if (!this.threeAvailable && typeof THREE === 'undefined') {
      console.log('Waiting for Three.js to load...');

      // Check multiple times with increasing intervals
      let attempts = 0;
      const checkThreeJs = () => {
        attempts++;
        if (typeof THREE !== 'undefined') {
          console.log('Three.js detected, proceeding with 3D visualization');
          this.threeAvailable = true;
          this.plotReciprocalLattice();
        } else if (attempts < 10) { // Try for up to 20 seconds
          setTimeout(checkThreeJs, 2000);
        } else {
          console.log('Three.js loading timed out after 20 seconds');
          this.showFallbackVisualization();
        }
      };

      setTimeout(checkThreeJs, 1000); // Start checking after 1 second
      return;
    }

    // If we get here, Three.js should be available
    if (typeof THREE !== 'undefined') {
      this.threeAvailable = true;
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
      this.scene = new THREE.Scene();
      this.scene.background = new THREE.Color(0x000011);

      // Setup orthographic camera for technical/scientific visualization
      const aspect = containerRect.width / containerRect.height;
      const frustumSize = 5;
      this.camera = new THREE.OrthographicCamera(
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
      this.renderer = new THREE.WebGLRenderer({ antialias: true });
      this.renderer.setSize(containerRect.width, containerRect.height);
      this.renderer.setPixelRatio(window.devicePixelRatio);

      // Ensure renderer canvas takes full width
      this.renderer.domElement.style.width = '100%';
      this.renderer.domElement.style.height = '100%';

      canvasContainer.appendChild(this.renderer.domElement);

      // Continue with the rest of the setup
      this.continueSetup();
    }, 100);
  }

  continueSetup() {
    // Initialize Three.js-dependent objects
    this.initializeThreeJsObjects();

    // Position camera first so setupOrbitNavigation can use the position
    this.positionCamera();

    // Setup orbit navigation controls with quaternions
    console.log('Setting up quaternion-based orbit navigation for reciprocal lattice viewer');
    this.setupOrbitNavigation();

    // Add coordinate axes
    // this.addAxes();

    // Create point cloud from reciprocal lattice data
    this.createPointCloud();

    // Add controls
    this.addControls();

    // Start animation loop
    this.startAnimation();

    // Handle window resize
    this.setupResizeHandler();

    console.log('3D reciprocal lattice visualization with orbit navigation created successfully');
  }

  initializeThreeJsObjects() {
    // Initialize Three.js-dependent objects now that Three.js is loaded
    this.orbitControls.target = new THREE.Vector3(0, 0, 0);
    
    this.mouseState.startPosition = new THREE.Vector2();
    this.mouseState.currentPosition = new THREE.Vector2();
    this.mouseState.deltaPosition = new THREE.Vector2();
    
    // Initialize simple camera state (CifVis approach)
    this.cameraState.position = new THREE.Vector3();
    this.cameraState.positionStart = new THREE.Vector3();
    this.cameraState.panOffset = new THREE.Vector3();
    
    console.log('Three.js objects initialized for CifVis-style rotation');
  }

  addAxes() {
    const axesHelper = new THREE.AxesHelper(2);
    this.scene.add(axesHelper);
  }

  setupOrbitNavigation() {
    const canvas = this.renderer.domElement;
    
    // Mouse event handlers
    canvas.addEventListener('mousedown', (event) => this.onMouseDown(event));
    canvas.addEventListener('mousemove', (event) => this.onMouseMove(event));
    canvas.addEventListener('mouseup', (event) => this.onMouseUp(event));
    canvas.addEventListener('mouseleave', (event) => this.onMouseUp(event)); // Treat mouse leaving canvas as mouseup
    canvas.addEventListener('wheel', (event) => this.onMouseWheel(event));
    canvas.addEventListener('contextmenu', (event) => event.preventDefault());

    // Touch event handlers for mobile support
    canvas.addEventListener('touchstart', (event) => this.onTouchStart(event));
    canvas.addEventListener('touchmove', (event) => this.onTouchMove(event));
    canvas.addEventListener('touchend', (event) => this.onTouchEnd(event));

    // Keyboard handlers for additional controls
    window.addEventListener('keydown', (event) => this.onKeyDown(event));

    console.log('CifVis-style navigation controls initialized');
  }

  onMouseDown(event) {
    if (!this.orbitControls.enabled) return;

    event.preventDefault();
    
    this.mouseState.isDown = true;
    this.mouseState.button = event.button;
    this.mouseState.startPosition.set(event.clientX, event.clientY);
    this.mouseState.currentPosition.copy(this.mouseState.startPosition);
  }

  onMouseMove(event) {
    if (!this.orbitControls.enabled || !this.mouseState.isDown) return;

    event.preventDefault();

    this.mouseState.currentPosition.set(event.clientX, event.clientY);
    this.mouseState.deltaPosition.subVectors(this.mouseState.currentPosition, this.mouseState.startPosition);

    const element = this.renderer.domElement;
    const rect = element.getBoundingClientRect();

    switch (this.mouseState.button) {
      case 0: // Left mouse button - rotate
        if (this.orbitControls.enableRotate) {
          // Convert to normalized device coordinates like CifVis
          const deltaX = this.mouseState.deltaPosition.x / rect.width * 2;
          const deltaY = this.mouseState.deltaPosition.y / rect.height * 2;
          this.rotateStructure(deltaX, deltaY);
        }
        break;
      
      case 1: // Middle mouse button - zoom
        if (this.orbitControls.enableZoom) {
          this.zoomCamera(this.mouseState.deltaPosition.y * 0.01);
        }
        break;
      
      case 2: // Right mouse button - pan
        if (this.orbitControls.enablePan) {
          this.panCamera(
            this.mouseState.deltaPosition.x / rect.width,
            this.mouseState.deltaPosition.y / rect.height
          );
        }
        break;
    }

    this.mouseState.startPosition.copy(this.mouseState.currentPosition);
  }

  onMouseUp(event) {
    if (!this.orbitControls.enabled) return;
    
    this.mouseState.isDown = false;
    this.mouseState.button = -1;
  }

  onMouseWheel(event) {
    if (!this.orbitControls.enabled || !this.orbitControls.enableZoom) return;

    event.preventDefault();

    const delta = event.deltaY > 0 ? 1 : -1;
    this.zoomCamera(delta * 0.1 * this.orbitControls.zoomSpeed);
  }

  onTouchStart(event) {
    if (!this.orbitControls.enabled) return;

    event.preventDefault();

    switch (event.touches.length) {
      case 1: // Single touch - rotate
        this.mouseState.startPosition.set(event.touches[0].pageX, event.touches[0].pageY);
        this.mouseState.currentPosition.copy(this.mouseState.startPosition);
        this.mouseState.isDown = true;
        this.mouseState.button = 0;
        break;
      
      case 2: // Two finger touch - zoom/pan
        const dx = event.touches[0].pageX - event.touches[1].pageX;
        const dy = event.touches[0].pageY - event.touches[1].pageY;
        this.touchDistance = Math.sqrt(dx * dx + dy * dy);
        
        this.mouseState.startPosition.set(
          (event.touches[0].pageX + event.touches[1].pageX) / 2,
          (event.touches[0].pageY + event.touches[1].pageY) / 2
        );
        this.mouseState.currentPosition.copy(this.mouseState.startPosition);
        this.mouseState.isDown = true;
        this.mouseState.button = 2;
        break;
    }
  }

  onTouchMove(event) {
    if (!this.orbitControls.enabled || !this.mouseState.isDown) return;

    event.preventDefault();

    switch (event.touches.length) {
      case 1: // Single touch - rotate
        this.mouseState.currentPosition.set(event.touches[0].pageX, event.touches[0].pageY);
        this.mouseState.deltaPosition.subVectors(this.mouseState.currentPosition, this.mouseState.startPosition);
        
        const touchElement = this.renderer.domElement;
        const touchRect = touchElement.getBoundingClientRect();
        
        // Convert to normalized device coordinates like CifVis
        const deltaX = this.mouseState.deltaPosition.x / touchRect.width * 2;
        const deltaY = this.mouseState.deltaPosition.y / touchRect.height * 2;
        this.rotateStructure(deltaX, deltaY);
        
        this.mouseState.startPosition.copy(this.mouseState.currentPosition);
        break;
      
      case 2: // Two finger touch - zoom/pan
        const dx = event.touches[0].pageX - event.touches[1].pageX;
        const dy = event.touches[0].pageY - event.touches[1].pageY;
        const distance = Math.sqrt(dx * dx + dy * dy);
        
        // Zoom based on pinch distance change
        const zoomDelta = (this.touchDistance - distance) / this.touchDistance;
        this.zoomCamera(zoomDelta * this.orbitControls.zoomSpeed);
        this.touchDistance = distance;
        
        // Pan based on center point movement
        this.mouseState.currentPosition.set(
          (event.touches[0].pageX + event.touches[1].pageX) / 2,
          (event.touches[0].pageY + event.touches[1].pageY) / 2
        );
        this.mouseState.deltaPosition.subVectors(this.mouseState.currentPosition, this.mouseState.startPosition);
        
        const panElement = this.renderer.domElement;
        const panRect = panElement.getBoundingClientRect();
        
        this.panCamera(
          this.mouseState.deltaPosition.x / panRect.width,
          this.mouseState.deltaPosition.y / panRect.height
        );
        
        this.mouseState.startPosition.copy(this.mouseState.currentPosition);
        break;
    }
  }

  onTouchEnd(event) {
    if (!this.orbitControls.enabled) return;
    
    this.mouseState.isDown = false;
    this.mouseState.button = -1;
  }

  onKeyDown(event) {
    if (!this.orbitControls.enabled) return;

    switch (event.code) {
      case 'KeyR': // Reset view
        this.resetView();
        break;
      case 'KeyA': // Toggle auto-rotate
        this.orbitControls.autoRotate = !this.orbitControls.autoRotate;
        break;
      case 'Space': // Stop auto-rotate
        event.preventDefault();
        this.orbitControls.autoRotate = false;
        break;
    }
  }

  rotateStructure(deltaX, deltaY) {
    if (!this.points) return;

    // Use CifVis approach: rotate the object, not the camera
    const rotationSpeed = this.orbitControls.rotateSpeed;
    const xAxis = new THREE.Vector3(-1, 0, 0);
    const yAxis = new THREE.Vector3(0, 1, 0);

    // Apply rotations to the point cloud using makeRotationAxis
    this.points.applyMatrix4(
      new THREE.Matrix4().makeRotationAxis(yAxis, deltaX * rotationSpeed)
    );
    this.points.applyMatrix4(
      new THREE.Matrix4().makeRotationAxis(xAxis, -deltaY * rotationSpeed)
    );
  }



  zoomCamera(zoomDelta) {
    if (this.camera.isPerspectiveCamera) {
      // For perspective camera, adjust distance
      const scaleFactor = Math.pow(0.95, this.orbitControls.zoomSpeed * zoomDelta);
      this.cameraState.distance *= scaleFactor;
      this.cameraState.distance = Math.max(this.orbitControls.minDistance, 
                                          Math.min(this.orbitControls.maxDistance, this.cameraState.distance));
    } else if (this.camera.isOrthographicCamera) {
      // For orthographic camera, adjust zoom property
      const scaleFactor = Math.pow(0.95, this.orbitControls.zoomSpeed * zoomDelta);
      this.camera.zoom = Math.max(0.1, Math.min(100, this.camera.zoom * scaleFactor));
      this.camera.updateProjectionMatrix();
      this.cameraState.zoomChanged = true;
    }
  }

  panCamera(deltaX, deltaY) {
    const element = this.renderer.domElement;
    
    if (this.camera.isPerspectiveCamera) {
      // Perspective camera panning
      const position = this.camera.position.clone();
      position.sub(this.orbitControls.target);
      const targetDistance = position.length();
      
      const fov = this.camera.fov * Math.PI / 180;
      const panOffset = {
        x: 2 * deltaX * targetDistance * Math.tan(fov / 2) * this.camera.aspect,
        y: 2 * deltaY * targetDistance * Math.tan(fov / 2)
      };
      
      this.panCameraByDistance(panOffset.x, panOffset.y);
      
    } else if (this.camera.isOrthographicCamera) {
      // Orthographic camera panning
      const panOffset = {
        x: deltaX * (this.camera.right - this.camera.left) / this.camera.zoom,
        y: deltaY * (this.camera.top - this.camera.bottom) / this.camera.zoom
      };
      
      this.panCameraByDistance(panOffset.x, panOffset.y);
    }
  }

  panCameraByDistance(deltaX, deltaY) {
    const v = new THREE.Vector3();
    
    // Pan left/right
    v.setFromMatrixColumn(this.camera.matrix, 0);
    v.multiplyScalar(-deltaX * this.orbitControls.panSpeed);
    this.cameraState.panOffset.add(v);
    
    // Pan up/down
    v.setFromMatrixColumn(this.camera.matrix, 1);
    v.multiplyScalar(deltaY * this.orbitControls.panSpeed);
    this.cameraState.panOffset.add(v);
  }

  resetView() {
    // Reset orbit controls target
    if (this.statistics.x && this.statistics.y && this.statistics.z) {
      const centerX = this.statistics.x.mean * 0.1;
      const centerY = this.statistics.y.mean * 0.1;
      const centerZ = this.statistics.z.mean * 0.1;
      this.orbitControls.target.set(centerX, centerY, centerZ);
      
      // Reset camera to look directly down Z axis
      this.camera.position.set(centerX, centerY, centerZ + 10);
    } else {
      this.orbitControls.target.set(0, 0, 0);
      
      // Reset camera to look directly down Z axis
      this.camera.position.set(0, 0, 10);
    }
    
    // Reset camera state
    this.cameraState.panOffset.set(0, 0, 0);
    this.cameraState.scale = 1;
    
    // Reset structure rotation to identity (CifVis approach)
    if (this.points) {
      this.points.matrix.identity();
      this.points.matrixAutoUpdate = false;
    }
    
    if (this.camera.isOrthographicCamera) {
      this.camera.zoom = 15;
      this.camera.updateProjectionMatrix();
    }
    
    this.camera.lookAt(this.orbitControls.target);
    
    console.log('View reset - Target:', this.orbitControls.target);
  }

  updateOrbitNavigation() {
    // CifVis approach: Keep camera fixed, rotate the structure
    // Camera simply looks at the target
    this.camera.lookAt(this.orbitControls.target);
    
    // Apply panning by moving the target
    if (this.cameraState.panOffset.length() > 0) {
      this.orbitControls.target.add(this.cameraState.panOffset);
      this.camera.lookAt(this.orbitControls.target);
    }
    
    // Apply damping
    if (this.orbitControls.enableDamping) {
      // Apply damping to pan offset
      this.cameraState.panOffset.multiplyScalar(1 - this.orbitControls.dampingFactor);
    } else {
      this.cameraState.panOffset.set(0, 0, 0);
    }
    
    // Auto-rotate feature - rotate the structure
    if (this.orbitControls.autoRotate && this.mouseState.button === -1 && this.points) {
      const autoRotationSpeed = 2 * Math.PI / 60 / 60 * this.orbitControls.autoRotateSpeed;
      const yAxis = new THREE.Vector3(0, 1, 0);
      this.points.applyMatrix4(
        new THREE.Matrix4().makeRotationAxis(yAxis, autoRotationSpeed)
      );
    }
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
    
    // Compute bounding box for debugging
    geometry.computeBoundingBox();

    // Create point material with appropriate size
    const material = new THREE.PointsMaterial({
      size: this.pointSize * 0.8, // Slightly smaller than default
      vertexColors: true,
      transparent: true,
      opacity: 0.9,
      sizeAttenuation: false // Keep consistent size regardless of distance
    });

    // Create points mesh
    this.points = new THREE.Points(geometry, material);
    this.scene.add(this.points);

    console.log(`Created point cloud with ${positions.length / 3} points`);
    console.log('Point cloud bounding box:', this.points.geometry.boundingBox);
    console.log('First few positions:', positions.slice(0, 9));
    console.log('Data range - R:', rMin, 'to', rMax);
  }

  getColorFromValue(normalizedValue) {
    // Bright cyan color for better visibility
    return { r: 0.0, g: 1.0, b: 1.0 };
  }

  positionCamera() {
    // Position camera looking directly down the world Z axis
    if (this.statistics.x && this.statistics.y && this.statistics.z) {
      const centerX = this.statistics.x.mean * 0.1;
      const centerY = this.statistics.y.mean * 0.1;
      const centerZ = this.statistics.z.mean * 0.1;

      // Set orbit target to data center
      this.orbitControls.target.set(centerX, centerY, centerZ);
      
      // Position camera directly above the target, looking down Z axis
      this.camera.position.set(centerX, centerY, centerZ + 10);
      this.camera.lookAt(this.orbitControls.target);
      
      console.log('Camera positioned at:', this.camera.position, 'looking at:', this.orbitControls.target);
    } else {
      // Default positioning - looking down Z axis
      this.orbitControls.target.set(0, 0, 0);
      this.camera.position.set(0, 0, 10);
      this.camera.lookAt(this.orbitControls.target);
      
      console.log('Default camera positioning at:', this.camera.position, 'looking at:', this.orbitControls.target);
    }

    // Set zoom level for orthographic camera
    if (this.camera.isOrthographicCamera) {
      this.camera.zoom = 15;
      this.camera.updateProjectionMatrix();
    }
    
    // Legacy controls compatibility
    if (this.controls) {
      this.controls.target.copy(this.orbitControls.target);
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
      <div class="d-flex align-items-center justify-content-center" style="font-size: 0.8rem;">
        <button id="${this.containerId}-reset" class="btn btn-sm btn-outline-primary">Reset View</button>
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
        this.resetView();
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

    // Update orbit navigation
    this.updateOrbitNavigation();

    // Update controls (legacy support)
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

    // Remove event listeners
    if (this.renderer && this.renderer.domElement) {
      const canvas = this.renderer.domElement;
      canvas.removeEventListener('mousedown', this.onMouseDown);
      canvas.removeEventListener('mousemove', this.onMouseMove);
      canvas.removeEventListener('mouseup', this.onMouseUp);
      canvas.removeEventListener('mouseleave', this.onMouseUp);
      canvas.removeEventListener('wheel', this.onMouseWheel);
      canvas.removeEventListener('contextmenu', (event) => event.preventDefault());
      canvas.removeEventListener('touchstart', this.onTouchStart);
      canvas.removeEventListener('touchmove', this.onTouchMove);
      canvas.removeEventListener('touchend', this.onTouchEnd);
    }

    // Remove keyboard event listener
    window.removeEventListener('keydown', this.onKeyDown);

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