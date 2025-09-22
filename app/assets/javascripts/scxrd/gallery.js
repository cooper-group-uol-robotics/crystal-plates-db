// Main SCXRD Gallery Functions

// Define function in global scope for SCXRD dataset switching
window.showScxrdDatasetInMain = function (datasetId, experimentName, datasetUrl, wellId, uniqueId = 'scxrd') {
  console.log('showScxrdDatasetInMain called with:', datasetId, experimentName, datasetUrl, uniqueId);

  // Update the main display panels
  fetch(`/wells/${wellId}/scxrd_datasets/${datasetId}`, {
    headers: { 'Accept': 'application/json' }
  })
    .then(response => response.json())
    .then(data => {
      // Update first diffraction image panel with interactive viewer
      const imagePanel = document.getElementById(`${uniqueId}-first-image-panel`);
      if (data.has_first_image) {
        // Show loading state
        imagePanel.innerHTML = `
          <div class="d-flex justify-content-center align-items-center h-100">
            <div class="text-center">
              <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">Loading...</span>
              </div>
              <div class="mt-2 small">Loading diffraction image...</div>
            </div>
          </div>
        `;

        // Load and display interactive diffraction viewer
        console.log('ScxrdDiffractionViewer available:', !!window.ScxrdDiffractionViewer);
        console.log('Visual Heatmap available:', !!window.VisualHeatmap);
        if (window.ScxrdDiffractionViewer) {
          // First, replace panel content with plot container
          const plotId = `${uniqueId}-diffraction-plot`;
          imagePanel.innerHTML = `
            <div class="position-relative h-100">
              <div id="${plotId}" style="width: 100%; height: 100%;"></div>
            </div>
          `;

          // Now create viewer and load data
          setTimeout(() => {
            const viewer = new window.ScxrdDiffractionViewer(plotId);
            viewer.showLoading();
            viewer.loadImageData(wellId, datasetId).then(success => {
              if (success) {
                viewer.plotImage();
              }
            });
          }, 100);
        } else {
          // Fallback if ScxrdDiffractionViewer is not available
          imagePanel.innerHTML = `
            <div class="text-center p-3">
              <i class="fas fa-camera fa-3x mb-3 text-primary"></i>
              <h6>First Frame</h6>
              <p class="text-muted small">Size: ${data.first_image_size}</p>
              <a href="/wells/${wellId}/scxrd_datasets/${datasetId}/download_first_image" 
                 class="btn btn-sm btn-primary">
                <i class="fas fa-download me-1"></i>Download
              </a>
            </div>
          `;
        }
      } else {
        imagePanel.innerHTML = `
          <div class="text-center p-3 text-muted">
            <i class="fas fa-camera fa-3x mb-3"></i>
            <h6>First Frame</h6>
            <p class="small">Not available</p>
          </div>
        `;
      }

      // Update peak table panel with interactive reciprocal lattice viewer
      const peakPanel = document.getElementById(`${uniqueId}-peak-table-panel`);
      if (data.has_peak_table) {
        // Show loading state
        peakPanel.innerHTML = `
          <div class="d-flex justify-content-center align-items-center h-100">
            <div class="text-center">
              <div class="spinner-border text-success" role="status">
                <span class="visually-hidden">Loading...</span>
              </div>
              <div class="mt-2 small">Loading reciprocal lattice...</div>
            </div>
          </div>
        `;

        // Load and display interactive reciprocal lattice viewer
        console.log('ScxrdReciprocalLatticeViewer available:', !!window.ScxrdReciprocalLatticeViewer);
        if (window.ScxrdReciprocalLatticeViewer) {
          // First, replace panel content with plot container
          const latticeId = `${uniqueId}-reciprocal-lattice-plot`;
          peakPanel.innerHTML = `
            <div class="position-relative" style="width: 100%; height: 100%;">
              <div id="${latticeId}" style="width: 100%; height: 100%;"></div>
            </div>
          `;

          // Now create viewer and load data
          setTimeout(() => {
            const viewer = new window.ScxrdReciprocalLatticeViewer(latticeId);
            viewer.showLoading();
            viewer.loadPeakTableData(wellId, datasetId).then(success => {
              if (success) {
                viewer.plotReciprocalLattice();
              }
            });
          }, 100);
        } else {
          // Fallback if ScxrdReciprocalLatticeViewer is not available
          peakPanel.innerHTML = `
            <div class="text-center p-3">
              <i class="fas fa-table fa-3x mb-3 text-success"></i>
              <h6>Reciprocal Lattice</h6>
              <p class="text-muted small">Size: ${data.peak_table_size}</p>
              <a href="/wells/${wellId}/scxrd_datasets/${datasetId}/download_peak_table" 
                 class="btn btn-sm btn-success">
                <i class="fas fa-download me-1"></i>Download
              </a>
            </div>
          `;
        }
      } else {
        peakPanel.innerHTML = `
          <div class="text-center p-3 text-muted">
            <i class="fas fa-table fa-3x mb-3"></i>
            <h6>Reciprocal Lattice</h6>
            <p class="small">Not available</p>
          </div>
        `;
      }

      // Update structure panel (placeholder)
      const structurePanel = document.getElementById(`${uniqueId}-structure-panel`);
      structurePanel.innerHTML = `
        <div class="text-center p-3">
          <i class="fas fa-cube fa-3x mb-3 text-info"></i>
          <h6>Crystal Structure</h6>
          <p class="text-muted small">3D visualization placeholder</p>
          <button class="btn btn-sm btn-info" disabled>
            <i class="fas fa-eye me-1"></i>View 3D
          </button>
        </div>
      `;

      // Update crystal image panel with well image and circle around closest point of interest
      const crystalImagePanel = document.getElementById(`${uniqueId}-crystal-image-panel`);
      if (data.real_world_coordinates && data.real_world_coordinates.x_mm !== null && data.real_world_coordinates.y_mm !== null) {
        crystalImagePanel.innerHTML = `
          <div class="position-relative w-100 h-100">
            <div id="crystal-well-image-container" class="w-100 h-100 d-flex align-items-center justify-content-center">
              <div class="text-center">
                <div class="spinner-border text-primary" role="status">
                  <span class="visually-hidden">Loading...</span>
                </div>
                <div class="mt-2 small">Loading well image...</div>
              </div>
            </div>
          </div>
        `;

        // Load well image with point of interest circle
        setTimeout(() => {
          window.loadWellImageWithCrystalLocation(datasetId, data.real_world_coordinates.x_mm, data.real_world_coordinates.y_mm, data.real_world_coordinates.z_mm, wellId);
        }, 100);
      } else {
        crystalImagePanel.innerHTML = `
          <div class="text-center p-3 text-muted">
            <i class="fas fa-gem fa-3x mb-3"></i>
            <h6>Crystal Image</h6>
            <p class="small">No crystal coordinates available</p>
          </div>
        `;
      }

      // Update experiment info card
      const infoCard = document.getElementById(`${uniqueId}-info-card`);
      let unitCellInfo = '';
      if (data.unit_cell && data.unit_cell.a) {
        unitCellInfo = `| Cell: a=${data.unit_cell.a}Å b=${data.unit_cell.b}Å c=${data.unit_cell.c}Å α=${data.unit_cell.alpha}° β=${data.unit_cell.beta}° γ=${data.unit_cell.gamma}°`;
      }

      infoCard.innerHTML = `
        <div class="card-body py-1">
          <div class="d-flex justify-content-between align-items-center">
            <div class="flex-grow-1 me-3">
              <span class="fw-bold">${experimentName}</span>
              <small class="text-muted ms-2">
                | Measured: ${data.date_measured || 'Unknown'}
                ${data.real_world_coordinates ? `| Position: (${data.real_world_coordinates.x_mm || 'N/A'}, ${data.real_world_coordinates.y_mm || 'N/A'}, ${data.real_world_coordinates.z_mm || 'N/A'})mm` : ''}
                ${unitCellInfo}
              </small>
            </div>
            <div class="btn-group btn-group-sm flex-shrink-0">
            <a href="${datasetUrl}" class="btn btn-outline-primary">
              <i class="fas fa-eye me-1"></i>View Details
            </a>
            <a href="${datasetUrl}/edit" class="btn btn-outline-secondary">
              <i class="fas fa-edit me-1"></i>Edit
            </a>
            ${data.has_archive ? `
              <a href="/wells/${wellId}/scxrd_datasets/${datasetId}/download" class="btn btn-outline-success">
                <i class="fas fa-download me-1"></i>Archive
              </a>
            ` : ''}
            </div>
          </div>
        </div>
      `;
    })
    .catch(error => {
      console.error('Error loading SCXRD dataset details:', error);
    });

  // Update thumbnail highlighting
  document.querySelectorAll('.scxrd-thumbnail').forEach(thumb => {
    thumb.classList.remove('border-primary');
  });
  const selectedThumb = document.querySelector(`[data-dataset-id="${datasetId}"]`);
  if (selectedThumb) {
    selectedThumb.classList.add('border-primary');
  }
};

// Function to load well image with crystal location circle
window.loadWellImageWithCrystalLocation = function (datasetId, crystalX, crystalY, crystalZ, wellId) {
  console.log(`Loading well image with crystal location: (${crystalX}, ${crystalY}, ${crystalZ})mm for dataset ${datasetId}`);

  const container = document.getElementById('crystal-well-image-container');
  if (!container) {
    console.error('Crystal well image container not found');
    return;
  }

  // For now, we'll use the spatial correlations endpoint but in a future improvement,
  // this should be split into separate endpoints for cleaner API architecture
  fetch(`/api/v1/wells/${wellId}/scxrd_datasets/spatial_correlations`, {
    headers: { 'Accept': 'application/json' }
  })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(correlationData => {
      console.log('Spatial correlations data:', correlationData);

      // Find the closest POI to the current crystal coordinates
      let closestPOI = null;
      let minDistance = Infinity;
      let matchingDataset = null;

      if (correlationData && correlationData.correlations && Array.isArray(correlationData.correlations)) {
        correlationData.correlations.forEach(correlation => {
          const dataset = correlation.scxrd_dataset;
          const pois = correlation.point_of_interests;

          // Check if this dataset matches our crystal coordinates (within small tolerance)
          if (dataset && dataset.real_world_coordinates) {
            const datasetCoords = dataset.real_world_coordinates;
            const datasetDistance = Math.sqrt(
              Math.pow(datasetCoords.x_mm - crystalX, 2) +
              Math.pow(datasetCoords.y_mm - crystalY, 2)
            );

            // If this dataset is close to our crystal location (within 0.1mm tolerance)
            if (datasetDistance < 0.1 && pois && Array.isArray(pois)) {
              pois.forEach(poi => {
                if (poi.distance_mm < minDistance) {
                  minDistance = poi.distance_mm;
                  closestPOI = poi;
                  matchingDataset = dataset;
                }
              });
            }
          }
        });
      }

      if (closestPOI && matchingDataset) {
        console.log(`Found spatial correlation: crystal at (${crystalX}, ${crystalY}) correlates with POI at pixel (${closestPOI.pixel_coordinates.x}, ${closestPOI.pixel_coordinates.y}) at distance ${minDistance.toFixed(3)}mm`);
        console.log(`Loading image with ID: ${closestPOI.image_id}`);

        // Fetch the image details to get the file URL
        fetch(`/api/v1/wells/${wellId}/images/${closestPOI.image_id}`, {
          headers: { 'Accept': 'application/json' }
        })
          .then(response => {
            if (!response.ok) {
              throw new Error(`HTTP ${response.status}: ${response.statusText}`);
            }
            return response.json();
          })
          .then(imageData => {
            console.log('Image data:', imageData);
            const imageUrl = imageData.data ? imageData.data.file_url : null;
            const pixelSizeX = imageData.data ? imageData.data.pixel_size_x_mm : null;
            const pixelSizeY = imageData.data ? imageData.data.pixel_size_y_mm : null;

            if (imageUrl && pixelSizeX && pixelSizeY) {
              // Load the specific image where the POI is defined with the circle overlay
              container.innerHTML = `
                <div class="position-relative w-100 h-100">
                  <img id="well-image-with-crystal" 
                       src="${imageUrl}" 
                       class="img-fluid w-100 h-100"
                       style="object-fit: contain;"
                       data-pixel-size-x="${pixelSizeX}"
                       data-pixel-size-y="${pixelSizeY}"
                       onload="window.drawCrystalLocationCircle(${closestPOI.pixel_coordinates.x}, ${closestPOI.pixel_coordinates.y})"
                       onerror="window.handleWellImageError()">
                  <canvas id="crystal-location-overlay" 
                          class="position-absolute top-0 start-0" 
                          style="pointer-events: none; z-index: 10;">
                  </canvas>
                </div>
              `;
            } else {
              throw new Error('Image URL or pixel size information not available');
            }
          })
          .catch(error => {
            console.error('Error loading image:', error);
            container.innerHTML = `
              <div class="text-center p-3 text-muted">
                <i class="fas fa-exclamation-triangle fa-3x mb-3"></i>
                <h6>Image Load Error</h6>
                <p class="small">Could not load image: ${error.message}</p>
              </div>
            `;
          });
      } else {
        console.log('No spatial correlations found for this crystal location');
        container.innerHTML = `
          <div class="text-center p-3 text-muted">
            <i class="fas fa-gem fa-3x mb-3"></i>
            <h6>Crystal Image</h6>
            <p class="small">No spatial correlations found for this crystal location</p>
          </div>
        `;
      }
    })
    .catch(error => {
      console.error('Error loading spatial correlations:', error);
      container.innerHTML = `
        <div class="text-center p-3 text-muted">
          <i class="fas fa-exclamation-triangle fa-3x mb-3"></i>
          <h6>Error</h6>
          <p class="small">Failed to load crystal location correlations</p>
        </div>
      `;
    });
}

// Function to draw circle around crystal location
window.drawCrystalLocationCircle = function (pixelX, pixelY) {
  const img = document.getElementById('well-image-with-crystal');
  const canvas = document.getElementById('crystal-location-overlay');

  if (!img || !canvas) {
    console.error('Image or canvas not found for drawing crystal circle');
    return;
  }

  // Set canvas size to match image display size
  const imgRect = img.getBoundingClientRect();
  canvas.width = imgRect.width;
  canvas.height = imgRect.height;

  const ctx = canvas.getContext('2d');

  // Calculate scaling factors
  const scaleX = imgRect.width / img.naturalWidth;
  const scaleY = imgRect.height / img.naturalHeight;

  // Scale pixel coordinates to canvas coordinates
  const canvasX = pixelX * scaleX;
  const canvasY = pixelY * scaleY;

  // Get actual pixel size from image data attributes
  const pixelSizeX = parseFloat(img.getAttribute('data-pixel-size-x')) || 0.01; // fallback to 0.01mm/pixel
  const pixelSizeY = parseFloat(img.getAttribute('data-pixel-size-y')) || 0.01; // fallback to 0.01mm/pixel

  // Calculate circle radius for 0.3mm using actual pixel size
  const radiusInPixelsX = 0.15 / pixelSizeX; // 0.3mm converted to pixels using X scale
  const radiusInPixelsY = 0.15 / pixelSizeY; // 0.3mm converted to pixels using Y scale

  // Use average radius and scale to display size
  const averageRadiusPixels = (radiusInPixelsX + radiusInPixelsY) / 2;
  const circleRadius = averageRadiusPixels * scaleX;

  // Draw circle
  ctx.strokeStyle = '#ff0000'; // Red circle
  ctx.lineWidth = 3;
  ctx.setLineDash([5, 5]); // Dashed line
  ctx.beginPath();
  ctx.arc(canvasX, canvasY, circleRadius, 0, 2 * Math.PI);
  ctx.stroke();

  // Draw center dot
  ctx.fillStyle = '#ff0000';
  ctx.setLineDash([]); // Solid line for dot
  ctx.beginPath();
  ctx.arc(canvasX, canvasY, 2, 0, 2 * Math.PI);
  ctx.fill();

  console.log(`Drew crystal location circle at (${canvasX.toFixed(1)}, ${canvasY.toFixed(1)}) with radius ${circleRadius.toFixed(1)}px`);
  console.log(`Using pixel scale: ${pixelSizeX}mm/px (X), ${pixelSizeY}mm/px (Y), 0.3mm = ${averageRadiusPixels.toFixed(1)} pixels`);
}

// Function to handle well image loading errors
window.handleWellImageError = function () {
  const container = document.getElementById('crystal-well-image-container');
  if (container) {
    container.innerHTML = `
      <div class="text-center p-3 text-muted">
        <i class="fas fa-image fa-3x mb-3"></i>
        <h6>Well Image</h6>
        <p class="small">Image not available</p>
      </div>
    `;
  }
}

console.log('SCXRD Gallery functions loaded');