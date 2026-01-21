// Main SCXRD Gallery Functions

// Define function in global scope for SCXRD dataset switching
window.showScxrdDatasetInMain = function (datasetId, experimentName, datasetUrl, wellId, uniqueId = 'scxrd') {


  // Use standalone API endpoint for all datasets
  const apiUrl = `/scxrd_datasets/${datasetId}`;

  // Find the specific dataset viewer container to avoid updating wrong headers on index page
  const datasetViewer = document.querySelector(`[data-dataset-id="${datasetId}"]`);
  if (!datasetViewer) {
    console.error(`Dataset viewer not found for dataset ID: ${datasetId}`);
    return;
  }

  // Update the main display panels
  fetch(apiUrl, {
    headers: { 'Accept': 'application/json' }
  })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      return response.json();
    })
    .then(data => {
      // Update dataset header information - look for header within the page structure
      // On index page, look for the main card header outside the dataset viewer
      // On show page, look for any header with h5
      let headerCard = null;
      
      // Try to find header in the parent card structure (index page)
      const parentCard = datasetViewer.closest('.card');
      if (parentCard) {
        headerCard = parentCard.querySelector('.card-header:has(h5)');
      }
      
      // Fallback to global search (show page)
      if (!headerCard) {
        headerCard = document.querySelector('.card-header:has(h5)');
      }
      if (headerCard) {
        // Update experiment name and link
        const titleLink = headerCard.querySelector('h5 a');
        if (titleLink) {
          titleLink.href = datasetUrl;
          titleLink.textContent = experimentName || `SCXRD Dataset #${datasetId}`;
        }

        // Update metadata section
        const metadataDiv = headerCard.querySelector('.text-muted.small');
        if (metadataDiv) {
          let metadataHTML = '';

          // Well information (if available)
          if (data.well) {
            const plateBarcode = data.well.plate.barcode;
            const wellLabel = data.well.label;
            metadataHTML += `<strong>Well:</strong> 
              <a href="/plates/${data.well.plate.id}" class="text-decoration-none" target="_blank">
                ${plateBarcode} ${wellLabel}
              </a>`;

            // Add coordinates if available
            if (data.real_world_coordinates &&
              data.real_world_coordinates.x_mm !== null) {
              metadataHTML += ` <span class="text-info ms-2">
                (x=${parseFloat(data.real_world_coordinates.x_mm).toFixed(2)}mm, 
                 y=${parseFloat(data.real_world_coordinates.y_mm).toFixed(2)}mm, 
                 z=${parseFloat(data.real_world_coordinates.z_mm || 0).toFixed(2)}mm)
              </span>`;
            }
            metadataHTML += ' | ';
          }

          // Measurement date
          const measuredDate = data.measured_at ?
            new Date(data.measured_at + ' UTC').toLocaleDateString('en-US', {
              year: 'numeric', month: 'short', day: 'numeric',
              hour: '2-digit', minute: '2-digit'
            }) :
            'Unknown date';
          metadataHTML += `<strong>Measured:</strong> ${measuredDate}`;

          // Spot statistics
          if (data.spots_found !== null && data.spots_found !== undefined) {
            let spotsHTML = ' | ';
            spotsHTML += `<strong>Spots:</strong> ${data.spots_found.toLocaleString()}`;
            
            if (data.spots_indexed !== null && data.spots_indexed !== undefined && data.spots_found > 0) {
              const indexedPercentage = ((data.spots_indexed / data.spots_found) * 100).toFixed(1);
              spotsHTML += ` (${indexedPercentage}% indexed)`;
            }
            metadataHTML += spotsHTML;
          }
          // Unit cell information (preferring conventional cell with centring)
          // Try display cell (conventional) first, then fall back to conventional_unit_cell, then primitive
          const cellData = data.unit_cell || data.conventional_unit_cell || data.primitive_unit_cell;
          if (cellData && cellData.a) {
            metadataHTML += `<br><strong>Unit Cell:</strong> `;
            if (cellData.bravais) {
              metadataHTML += `<span class="badge bg-secondary me-1">${cellData.bravais}</span> `;
            }
            metadataHTML += `a=${cellData.a} `;
            metadataHTML += `b=${cellData.b} `;
            metadataHTML += `c=${cellData.c} `;
            metadataHTML += `α=${cellData.alpha}° `;
            metadataHTML += `β=${cellData.beta}° `;
            metadataHTML += `γ=${cellData.gamma}°`;
          }

          metadataDiv.innerHTML = metadataHTML;
        }

        // Update G6 comparison button and download links
        const actionDiv = headerCard.querySelector('.text-end .d-flex');
        if (actionDiv) {
          let actionsHTML = '';

          // Add G6 comparison button if unit cell is available (check any unit cell type)
          const hasCellData = (data.unit_cell && data.unit_cell.a) || 
                             (data.conventional_unit_cell && data.conventional_unit_cell.a) || 
                             (data.primitive_unit_cell && data.primitive_unit_cell.a);
          if (hasCellData) {
            actionsHTML += `
              <button type="button" class="btn btn-outline-info btn-sm similarity-button me-2"
                      data-g6-comparison-target="similarityButton"
                      data-dataset-id="${datasetId}"
                      data-action="click->g6-comparison#loadG6Comparison">
                <i class="bi bi-box-seam me-1"></i>
                <span class="similarity-text">Loading...</span>
              </button>
            `;
          }

          // Action buttons group
          actionsHTML += `
            <div class="btn-group btn-group-sm">
              <a href="${datasetUrl}" class="btn btn-outline-primary btn-sm" target="_blank">
                <i class="bi bi-eye"></i> Details
              </a>
          `;

          if (data.has_archive) {
            actionsHTML += `
              <a href="${datasetUrl}/download" class="btn btn-outline-success btn-sm">
                <i class="bi bi-download"></i> Archive
              </a>
            `;
          }

          actionsHTML += '</div>';
          actionDiv.innerHTML = actionsHTML;

          // Load similarity counts for the newly created button
          if (hasCellData) {
            const newButton = actionDiv.querySelector(`[data-dataset-id="${datasetId}"]`);
            if (newButton) {
              loadSimilarityCountForButton(newButton, datasetId);
            }
          }
        }
      }
      // Update diffraction image panel with interactive viewer
      const imagePanel = document.getElementById(`${uniqueId}-diffraction-image-panel`);
      if (data.has_diffraction_images) {
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

        if (window.ScxrdDiffractionViewer) {
          // First, replace panel content with plot container
          const plotId = `${uniqueId}-diffraction-plot`;
          imagePanel.innerHTML = `
            <div class="position-relative h-100">
              <div id="${plotId}" style="width: 100%; height: 100%;"></div>
            </div>
          `;

          // Now create viewer and load data
          setTimeout(async () => {
            const viewer = new window.ScxrdDiffractionViewer(plotId);
            viewer.showLoading();

            // Store well and dataset IDs for navigation
            viewer.wellId = wellId;
            viewer.datasetId = datasetId;

            // Load diffraction images list first (for navigation)
            await viewer.loadDiffractionImagesList(wellId, datasetId);

            // Load the first available diffraction image, or fall back to legacy first image
            let success = false;
            if (viewer.diffractionImages && viewer.diffractionImages.length > 0) {
              // Load the first diffraction image from the new system
              success = await viewer.loadImageData(wellId, datasetId, viewer.diffractionImages[0].id);
            } else {
              // Fall back to legacy first image
              success = await viewer.loadImageData(wellId, datasetId);
            }

            if (success) {
              viewer.plotImage();
            }
          }, 100);
        } else {
          // Fallback if ScxrdDiffractionViewer is not available
          imagePanel.innerHTML = `
            <div class="text-center p-3">
              <i class="fas fa-camera fa-3x mb-3 text-primary"></i>
              <h6>Diffraction Images</h6>
              <p class="text-muted small">${data.diffraction_images_count} images available</p>
              <button class="btn btn-sm btn-primary" disabled>
                <i class="fas fa-play me-1"></i>Interactive viewer loading...
              </button>
            </div>
          `;
        }
      } else {
        imagePanel.innerHTML = `
          <div class="text-center p-3 text-muted">
            <i class="fas fa-camera fa-3x mb-3"></i>
            <h6>Diffraction Images</h6>
            <p class="small">No diffraction images available</p>
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
              <a href="/scxrd_datasets/${datasetId}/download_peak_table" 
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

      // Structure panel is handled by the ERB template - don't override it
      // The 3D viewer is embedded directly in the template based on has_structure_file?

      // Update crystal image panel with well image, crystal image, or fallback
      const crystalImagePanel = document.getElementById(`${uniqueId}-crystal-image-panel`);

      // Check if we should show well image with coordinates
      const hasCoordinates = data.real_world_coordinates &&
        data.real_world_coordinates.x_mm !== null &&
        data.real_world_coordinates.y_mm !== null;

      if (hasCoordinates && wellId) {
        // First try to load well image with coordinate circle
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
          const containerId = `${uniqueId}-crystal-image-panel`;
          window.loadWellImageWithCrystalLocation(datasetId, data.real_world_coordinates.x_mm, data.real_world_coordinates.y_mm, data.real_world_coordinates.z_mm, wellId, containerId);
        }, 100);
      } else if (data.has_crystal_image) {
        // Show crystal image from archive if no coordinates or no well
        crystalImagePanel.innerHTML = `
          <div class="position-relative w-100 h-100">
            <img src="${datasetUrl}/crystal_image" 
                 alt="Crystal Image" 
                 class="img-fluid w-100 h-100" 
                 style="object-fit: contain;">
          </div>
        `;
      } else {
        // Fallback message
        crystalImagePanel.innerHTML = `
          <div class="text-center p-3 text-muted">
            <i class="fas fa-gem fa-3x mb-3"></i>
            <h6>Crystal Image</h6>
            <p class="small">No crystal image or coordinates available</p>
          </div>
        `;
      }


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
window.loadWellImageWithCrystalLocation = function (datasetId, crystalX, crystalY, crystalZ, wellId, containerId = 'crystal-well-image-container') {


  const container = document.getElementById(containerId);
  if (!container) {
    console.error(`Crystal well image container not found: ${containerId}`);
    return;
  }

  // Handle standalone datasets (no well association)
  if (!wellId || wellId === 'null' || wellId === null) {

    container.innerHTML = `
      <div class="text-center p-3 text-muted">
        <i class="fas fa-info-circle fa-2x mb-3"></i>
        <div><strong>Standalone Dataset</strong></div>
        <div class="small">No well image available</div>
        <div class="small mt-2">Crystal coordinates: (${crystalX != null && !isNaN(parseFloat(crystalX)) ? parseFloat(crystalX).toFixed(3) : 'N/A'}, ${crystalY != null && !isNaN(parseFloat(crystalY)) ? parseFloat(crystalY).toFixed(3) : 'N/A'}, ${crystalZ != null && !isNaN(parseFloat(crystalZ)) ? parseFloat(crystalZ).toFixed(3) : 'N/A'}) mm</div>
      </div>
    `;
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

// Function to load similarity count for a specific button
window.loadSimilarityCountForButton = function (button, datasetId) {
  const textSpan = button.querySelector('.similarity-text');

  if (!textSpan) return;

  fetch(`/scxrd_datasets/${datasetId}/similarity_counts`)
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        const g6Count = data.g6_count || 0;
        const csdCount = data.csd_count || 0;
        const totalCount = g6Count + csdCount;

        if (totalCount > 0) {
          textSpan.textContent = `${g6Count} local + ${csdCount} CSD matches`;
          button.classList.remove('btn-outline-secondary');
          button.classList.add('btn-outline-info', 'has-matches');
          button.disabled = false;
        } else {
          textSpan.textContent = 'No similar unit cells';
          button.classList.remove('btn-outline-info');
          button.classList.add('btn-outline-secondary');
          button.disabled = true;
        }
      } else {
        textSpan.textContent = 'No unit cell data';
        button.classList.remove('btn-outline-info');
        button.classList.add('btn-outline-secondary');
        button.disabled = true;
      }
    })
    .catch(error => {
      console.error('Error loading similarity counts:', error);
      textSpan.textContent = 'Error loading';
      button.classList.remove('btn-outline-info');
      button.classList.add('btn-outline-secondary');
      button.disabled = true;
    });
};

console.log('SCXRD Gallery functions loaded');