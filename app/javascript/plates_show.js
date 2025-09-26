// Plates Show Page JavaScript
// Enhanced with error handling, performance optimizations, and better structure

'use strict';

console.log('plates_show.js is loading...');

// Constants
const CONSTANTS = {
  SEARCH_DEBOUNCE_DELAY: 300,
  MESSAGE_AUTO_HIDE_DELAY: 3000,
  DROPDOWN_HIDE_DELAY: 200,
  IMAGE_LOAD_TIMEOUT: 10000,
  // Keyboard shortcuts
  SHORTCUTS: {
    TOGGLE_SELECT_MODE: 's',
    EDIT_SELECTED: 'e',
    CLEAR_SELECTION: 'c',
    ESCAPE: 'Escape'
  }
};

// Utility functions
const Utils = {
  debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
      const later = () => {
        clearTimeout(timeout);
        func(...args);
      };
      clearTimeout(timeout);
      timeout = setTimeout(later, wait);
    };
  },

  getCsrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]');
    if (!token) {
      console.error('CSRF token not found');
      return null;
    }
    return token.getAttribute('content');
  },

  showLoadingSpinner(element) {
    if (element) {
      element.innerHTML = '<div class="loading-spinner"></div>';
    }
  },

  handleApiError(error, context = 'API call') {
    console.error(`Error in ${context}:`, error);
    return `Error: ${error.message || 'Unknown error occurred'}`;
  }
};

// Global functions for image management
window.showImageInMain = function (imageId, imageUrl, largeImageUrl) {
  try {
    const mainImage = document.querySelector('img[id^="main-image-"]');
    const thumbnailImage = document.getElementById(`thumb-image-${imageId}`);
    const thumbnail = thumbnailImage?.closest('.image-thumbnail');

    if (!mainImage || !thumbnailImage || !thumbnail) {
      console.warn('Required elements not found for image switching');
      return;
    }

    const imageSrc = largeImageUrl || thumbnailImage.src;

    // Add loading state
    mainImage.style.opacity = '0.5';

    // Create a new image to preload
    const tempImage = new Image();
    tempImage.onload = function () {
      mainImage.src = imageSrc;
      mainImage.id = `main-image-${imageId}`;
      mainImage.style.opacity = '1';

      // Update related elements
      ImageManager.updateImageElements(imageId, imageUrl, thumbnail);
    };

    tempImage.onerror = function () {
      console.error('Failed to load image:', imageSrc);
      mainImage.style.opacity = '1';
    };

    // Set timeout for image loading
    setTimeout(() => {
      if (tempImage.complete === false) {
        console.warn('Image loading timeout');
        mainImage.style.opacity = '1';
      }
    }, CONSTANTS.IMAGE_LOAD_TIMEOUT);

    tempImage.src = imageSrc;

  } catch (error) {
    console.error('Error in showImageInMain:', error);
  }
};

const ImageManager = {
  updateImageElements(imageId, imageUrl, thumbnail) {
    try {
      // Update main image link
      const mainImageLink = document.getElementById('main-image-link');
      if (mainImageLink) {
        mainImageLink.href = imageUrl;
      }

      // Update image info overlay
      const imageInfo = thumbnail.getAttribute('data-image-info');
      const infoOverlay = document.getElementById('image-info-overlay');
      if (infoOverlay && imageInfo) {
        infoOverlay.innerHTML = `<small>${imageInfo}</small>`;
      }

      // Update header info
      const capturedDate = thumbnail.getAttribute('data-image-captured');
      const headerInfo = document.getElementById('current-image-info');
      if (headerInfo) {
        headerInfo.innerHTML = capturedDate ? `Captured: ${capturedDate}` : '';
      }

      // Update description
      const description = thumbnail.getAttribute('data-image-description');
      const descriptionElement = document.getElementById('current-image-description');
      if (descriptionElement) {
        descriptionElement.textContent = description || '';
      }

      // Update action buttons
      this.updateActionButtons(imageId, imageUrl);

      // Update thumbnail highlighting
      this.updateThumbnailHighlighting(thumbnail);

    } catch (error) {
      console.error('Error updating image elements:', error);
    }
  },

  updateActionButtons(imageId, imageUrl) {
    const actionsContainer = document.getElementById('main-image-actions');
    if (actionsContainer) {
      const viewButton = actionsContainer.querySelector('.btn-outline-primary');
      const editButton = actionsContainer.querySelector('.btn-outline-secondary');
      if (viewButton) viewButton.href = imageUrl;
      if (editButton) editButton.href = imageUrl.replace(/\/\d+$/, `/${imageId}/edit`);
    }
  },

  updateThumbnailHighlighting(activeThumbnail) {
    document.querySelectorAll('.image-thumbnail').forEach(thumb => {
      thumb.classList.remove('border-primary');
    });
    activeThumbnail.classList.add('border-primary');
  }
};

// Well selection and multi-select functionality
class WellSelector {
  constructor() {
    this.selectMode = false;
    this.selectedWells = new Set();
    this.init();
  }

  init() {
    this.bindEvents();
  }

  bindEvents() {
    const selectModeSwitch = document.getElementById('selectModeSwitch');
    const editMultipleWellsBtn = document.getElementById('editMultipleWellsBtn');
    const wellButtons = document.querySelectorAll('.well-select-btn');

    if (selectModeSwitch) {
      selectModeSwitch.addEventListener('change', (e) => {
        this.selectMode = e.target.checked;
        this.selectedWells.clear();
        wellButtons.forEach(btn => {
          btn.classList.remove('border-info', 'shadow');
          if (this.selectMode) {
            btn.removeAttribute('data-bs-toggle');
            btn.removeAttribute('data-bs-target');
          } else {
            btn.setAttribute('data-bs-toggle', 'modal');
            btn.setAttribute('data-bs-target', '#wellImagesModal');
          }
        });
        this.setHeaderButtonsState(this.selectMode);
        this.updateEditButton();
      });
    }

    wellButtons.forEach(btn => {
      btn.addEventListener('click', (event) => {
        if (this.selectMode) {
          event.preventDefault();
          const wellId = btn.getAttribute('data-well-id');
          if (this.selectedWells.has(wellId)) {
            this.selectedWells.delete(wellId);
            btn.classList.remove('border-info', 'shadow');
          } else {
            this.selectedWells.add(wellId);
            btn.classList.add('border-info', 'shadow');
          }
          this.updateEditButton();
        }
      });
    });

    // Header button events
    document.querySelectorAll('.row-header-btn').forEach(btn => {
      btn.addEventListener('click', (event) => {
        if (this.selectMode) {
          event.preventDefault();
          const row = btn.getAttribute('data-row');
          this.selectRow(row);
        }
      });
    });

    document.querySelectorAll('.col-header-btn').forEach(btn => {
      btn.addEventListener('click', (event) => {
        if (this.selectMode) {
          event.preventDefault();
          const col = btn.getAttribute('data-col');
          this.selectColumn(col);
        }
      });
    });

    document.querySelectorAll('.subwell-header-btn').forEach(btn => {
      btn.addEventListener('click', (event) => {
        if (this.selectMode) {
          event.preventDefault();
          const subwell = btn.getAttribute('data-subwell');
          this.selectSubwell(subwell);
        }
      });
    });

    if (editMultipleWellsBtn) {
      editMultipleWellsBtn.addEventListener('click', () => {
        if (this.selectedWells.size === 0) return;
        this.openBulkEditModal();
      });
    }
  }

  updateEditButton() {
    const editMultipleWellsBtn = document.getElementById('editMultipleWellsBtn');
    if (!editMultipleWellsBtn) return;

    if (this.selectedWells.size > 0) {
      editMultipleWellsBtn.classList.remove('d-none');
      editMultipleWellsBtn.disabled = false;
      editMultipleWellsBtn.textContent = `Edit multiple wells (${this.selectedWells.size})`;
    } else {
      editMultipleWellsBtn.classList.add('d-none');
      editMultipleWellsBtn.disabled = true;
      editMultipleWellsBtn.textContent = 'Edit multiple wells';
    }
  }

  setHeaderButtonsState(enabled) {
    document.querySelectorAll('.row-header-btn, .col-header-btn, .subwell-header-btn').forEach(btn => {
      btn.disabled = !enabled;
    });
  }

  selectRow(row) {
    const wellButtons = document.querySelectorAll('.well-select-btn');
    let allSelected = true;

    wellButtons.forEach(btn => {
      if (btn.getAttribute('data-row') == row) {
        const wellId = btn.getAttribute('data-well-id');
        if (!this.selectedWells.has(wellId)) {
          allSelected = false;
        }
      }
    });

    if (allSelected) {
      // Deselect all wells in the row
      wellButtons.forEach(btn => {
        if (btn.getAttribute('data-row') == row) {
          const wellId = btn.getAttribute('data-well-id');
          this.selectedWells.delete(wellId);
          btn.classList.remove('border-info', 'shadow');
        }
      });
    } else {
      // Select all wells in the row
      wellButtons.forEach(btn => {
        if (btn.getAttribute('data-row') == row) {
          const wellId = btn.getAttribute('data-well-id');
          if (!this.selectedWells.has(wellId)) {
            this.selectedWells.add(wellId);
            btn.classList.add('border-info', 'shadow');
          }
        }
      });
    }
    this.updateEditButton();
  }

  selectColumn(col) {
    const wellButtons = document.querySelectorAll('.well-select-btn');
    let allSelected = true;

    wellButtons.forEach(btn => {
      if (btn.getAttribute('data-col') == col) {
        const wellId = btn.getAttribute('data-well-id');
        if (!this.selectedWells.has(wellId)) {
          allSelected = false;
        }
      }
    });

    if (allSelected) {
      // Deselect all wells in the column
      wellButtons.forEach(btn => {
        if (btn.getAttribute('data-col') == col) {
          const wellId = btn.getAttribute('data-well-id');
          this.selectedWells.delete(wellId);
          btn.classList.remove('border-info', 'shadow');
        }
      });
    } else {
      // Select all wells in the column
      wellButtons.forEach(btn => {
        if (btn.getAttribute('data-col') == col) {
          const wellId = btn.getAttribute('data-well-id');
          if (!this.selectedWells.has(wellId)) {
            this.selectedWells.add(wellId);
            btn.classList.add('border-info', 'shadow');
          }
        }
      });
    }
    this.updateEditButton();
  }

  selectSubwell(subwell) {
    const wellButtons = document.querySelectorAll('.well-select-btn');
    let allSelected = true;

    wellButtons.forEach(btn => {
      if (btn.getAttribute('data-subwell') == subwell) {
        const wellId = btn.getAttribute('data-well-id');
        if (!this.selectedWells.has(wellId)) {
          allSelected = false;
        }
      }
    });

    if (allSelected) {
      // Deselect all wells in the subwell
      wellButtons.forEach(btn => {
        if (btn.getAttribute('data-subwell') == subwell) {
          const wellId = btn.getAttribute('data-well-id');
          this.selectedWells.delete(wellId);
          btn.classList.remove('border-info', 'shadow');
        }
      });
    } else {
      // Select all wells in the subwell
      wellButtons.forEach(btn => {
        if (btn.getAttribute('data-subwell') == subwell) {
          const wellId = btn.getAttribute('data-well-id');
          if (!this.selectedWells.has(wellId)) {
            this.selectedWells.add(wellId);
            btn.classList.add('border-info', 'shadow');
          }
        }
      });
    }
    this.updateEditButton();
  }

  openBulkEditModal() {
    const wellIds = Array.from(this.selectedWells);
    const modalHtml = `
      <div class="modal fade" id="editMultipleWellsModal" tabindex="-1" aria-labelledby="editMultipleWellsModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-xl modal-dialog-centered">
          <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title" id="editMultipleWellsModalLabel">Edit Multiple Wells</h5>
              <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body" style="max-height: 80vh; overflow-y: auto;">
              <div class="tab-content mt-3" id="bulkWellTabContent">
                <div class="tab-pane fade show active" id="bulk-content" role="tabpanel" aria-labelledby="bulk-content-tab">
                  <form id="bulkStockSolutionForm">
                    <div class="mb-3">
                      <h6>Add Stock Solution</h6>
                      <div class="row">
                        <div class="col-md-8">
                          <label for="bulkStockSolutionSearch" class="form-label">Stock Solution</label>
                          <input type="text" class="form-control" id="bulkStockSolutionSearch" placeholder="Search stock solution..." autocomplete="off">
                          <input type="hidden" id="bulkStockSolutionId">
                          <div id="bulkStockSolutionResults" class="dropdown-menu" style="max-height: 200px;overflow-y: auto;"></div>
                        </div>
                        <div class="col-md-4">
                          <label for="bulkVolumeAmountInput" class="form-label">Volume with unit</label>
                          <input type="text" class="form-control" id="bulkVolumeAmountInput" placeholder="e.g. 50 μL">
                        </div>
                      </div>
                    </div>
                    <button type="submit" class="btn btn-primary">Add to selected wells</button>
                  </form>
                  <div id="bulkContentMessages" class="mt-2"></div>
                </div>
              </div>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
            </div>
          </div>
        </div>
      </div>
    `;

    // Remove any existing modal
    const existingModal = document.getElementById('editMultipleWellsModal');
    if (existingModal) existingModal.remove();

    document.body.insertAdjacentHTML('beforeend', modalHtml);
    const modalEl = document.getElementById('editMultipleWellsModal');
    const modal = new bootstrap.Modal(modalEl);
    modal.show();

    // Wait for modal to be fully shown before attaching event listeners
    modalEl.addEventListener('shown.bs.modal', () => {
      this.setupBulkEditModal(wellIds);
    });
  }

  setupBulkEditModal(wellIds) {
    const bulkSearchInput = document.getElementById('bulkStockSolutionSearch');
    const bulkResultsDiv = document.getElementById('bulkStockSolutionResults');
    const bulkForm = document.getElementById('bulkStockSolutionForm');
    const bulkContentMessages = document.getElementById('bulkContentMessages');

    if (!bulkSearchInput || !bulkResultsDiv || !bulkForm) return;

    bulkSearchInput.addEventListener('input', function () {
      const query = bulkSearchInput.value.trim();
      if (query.length < 2) {
        bulkResultsDiv.classList.remove('show');
        bulkResultsDiv.classList.add('d-none');
        return;
      }
      fetch(`/stock_solutions/search?q=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
        .then(response => response.json())
        .then(data => {
          if (data.length === 0) {
            bulkResultsDiv.innerHTML = '<div class="dropdown-item text-muted">No stock solutions found</div>';
          } else {
            bulkResultsDiv.innerHTML = data.map(solution =>
              `<button type="button" class="dropdown-item" 
                     data-solution-id="${solution.id}" 
                     data-solution-name="${solution.display_name}">
              <strong>${solution.display_name}</strong>
              ${solution.component_summary ? `<br><small class="text-muted">${solution.component_summary}</small>` : ''}
            </button>`
            ).join('');
          }
          bulkResultsDiv.classList.remove('d-none');
          bulkResultsDiv.classList.add('show');
        });
    });

    bulkResultsDiv.addEventListener('click', function (event) {
      const target = event.target.closest('.dropdown-item');
      if (target && target.dataset.solutionId) {
        document.getElementById('bulkStockSolutionId').value = target.dataset.solutionId;
        bulkSearchInput.value = target.dataset.solutionName;
        bulkResultsDiv.classList.remove('show');
        bulkResultsDiv.classList.add('d-none');
      }
    });

    // Hide dropdown on blur
    bulkSearchInput.addEventListener('blur', function () {
      setTimeout(() => {
        bulkResultsDiv.classList.remove('show');
        bulkResultsDiv.classList.add('d-none');
      }, 200);
    });

    bulkForm.addEventListener('submit', function (event) {
      event.preventDefault();
      const stockSolutionId = document.getElementById('bulkStockSolutionId').value;
      const volumeWithUnit = document.getElementById('bulkVolumeAmountInput').value.trim();

      if (!stockSolutionId) {
        bulkContentMessages.innerHTML = '<div class="alert alert-danger">Please select a stock solution</div>';
        return;
      }
      if (!volumeWithUnit) {
        bulkContentMessages.innerHTML = '<div class="alert alert-danger">Please enter a volume with unit (e.g., 50 μL)</div>';
        return;
      }

      const csrfToken = document.querySelector('meta[name="csrf-token"]');
      if (!csrfToken) {
        bulkContentMessages.innerHTML = '<div class="alert alert-danger">CSRF token not found</div>';
        return;
      }

      fetch('/wells/bulk_add_content', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken.getAttribute('content')
        },
        body: JSON.stringify({
          well_ids: wellIds,
          stock_solution_id: stockSolutionId,
          volume_with_unit: volumeWithUnit
        })
      })
        .then(response => response.json())
        .then(data => {
          if (data.status === 'success') {
            bulkContentMessages.innerHTML = `<div class="alert alert-success">${data.message}</div>`;
          } else {
            bulkContentMessages.innerHTML = `<div class="alert alert-danger">${data.message || 'Bulk add failed'}</div>`;
          }
        })
        .catch(error => {
          bulkContentMessages.innerHTML = `<div class="alert alert-danger">Error: ${error.message}</div>`;
        });
    });
  }
}

// Well modal functionality
class WellModal {
  constructor() {
    this.modal = document.getElementById('wellImagesModal');
    this.contentContainer = document.getElementById('wellContentForm');
    this.currentWellId = null;
    this.pxrdLoaded = false;
    this.scxrdLoaded = false;
    
    // Only initialize if modal exists
    if (this.modal && this.contentContainer) {
      this.init();
    }
  }

  init() {
    if (!this.modal) return;

    this.modal.addEventListener('show.bs.modal', (event) => {
      this.handleModalShow(event);
      // Bind tab listeners when modal is shown (tabs are now in DOM)
      this.bindTabListeners();
    });

    this.modal.addEventListener('hidden.bs.modal', () => {
      console.log('Modal closed, refreshing page to update well colors...');
      this.pxrdLoaded = false; // Reset for next time
      this.scxrdLoaded = false; // Reset for next time
      window.location.reload();
    });

    if (this.contentContainer) {
      this.bindContentEvents();
    }
  }

  bindTabListeners() {
    // Add tab click listeners for lazy loading - only when modal is shown
    const pxrdTab = document.getElementById('pxrd-tab');
    if (pxrdTab && !pxrdTab.hasAttribute('data-listener-bound')) {
      pxrdTab.addEventListener('click', () => {
        if (this.currentWellId && !this.pxrdLoaded) {
          this.loadPxrdTab(this.currentWellId);
          this.pxrdLoaded = true;
        }
      });
      pxrdTab.setAttribute('data-listener-bound', 'true');
    }

    const scxrdTab = document.getElementById('scxrd-tab');
    if (scxrdTab && !scxrdTab.hasAttribute('data-listener-bound')) {
      scxrdTab.addEventListener('click', () => {
        if (this.currentWellId && !this.scxrdLoaded) {
          this.loadScxrdTab(this.currentWellId);
          this.scxrdLoaded = true;
        }
      });
      scxrdTab.setAttribute('data-listener-bound', 'true');
    }
  }

  handleModalShow(event) {
    console.log('Modal show event triggered');
    const button = event.relatedTarget;
    const wellId = button.getAttribute('data-well-id');
    const wellLabel = button.getAttribute('data-well-label');

    console.log('Button:', button);
    console.log('Well ID:', wellId);
    console.log('Well Label:', wellLabel);

    if (!wellId) {
      document.getElementById('wellImagesContent').innerHTML = '<p>No well selected.</p>';
      document.getElementById('wellContentForm').innerHTML = '<p>No well selected.</p>';
      document.getElementById('wellImagesModalLabel').textContent = 'Well Details';
      return;
    }

    // Store current well ID for lazy loading
    this.currentWellId = wellId;
    this.pxrdLoaded = false;
    this.scxrdLoaded = false;

    // Update modal title immediately
    document.getElementById('wellImagesModalLabel').textContent = `Well ${wellLabel} Details`;

    // Show immediate loading states for all tabs
    document.getElementById('wellImagesContent').innerHTML = `
      <div class="text-center py-3">
        <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
          <span class="visually-hidden">Loading images...</span>
        </div>
        <div class="text-muted small">Loading images...</div>
      </div>
    `;

    document.getElementById('wellContentForm').innerHTML = `
      <div class="text-center py-3">
        <div class="spinner-border spinner-border-sm text-secondary mb-2" role="status">
          <span class="visually-hidden">Loading content...</span>
        </div>
        <div class="text-muted small">Loading content...</div>
      </div>
    `;

    // Load images tab with priority
    setTimeout(() => this.loadImagesTab(wellId), 0);

    // Load content tab with slight delay
    setTimeout(() => this.loadContentTab(wellId), 50);

    // Show placeholder in PXRD tab for lazy loading
    document.getElementById('wellPxrdContent').innerHTML = `
      <div class="text-center py-4 text-muted">
        <i class="fas fa-chart-line fa-2x mb-2"></i>
        <div>Click to load PXRD patterns</div>
        <small>PXRD data will be loaded when you view this tab</small>
      </div>
    `;

    // Show placeholder in SCXRD tab for lazy loading
    document.getElementById('wellScxrdContent').innerHTML = `
      <div class="text-center py-4 text-muted">
        <i class="fas fa-cube fa-2x mb-2"></i>
        <div>Click to load SCXRD datasets</div>
        <small>SCXRD data will be loaded when you view this tab</small>
      </div>
    `;
  }

  loadImagesTab(wellId) {
    const startTime = performance.now();
    const container = document.getElementById('wellImagesContent');

    // Show immediate loading state
    container.innerHTML = `
      <div class="text-center py-3">
        <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
          <span class="visually-hidden">Loading images...</span>
        </div>
        <div class="text-muted small">Loading images...</div>
      </div>
    `;

    fetch(`/wells/${wellId}/images`, {
      method: 'GET',
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest',
        // Add cache headers for better performance
        'Cache-Control': 'max-age=300'
      }
    })
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.text();
      })
      .then(html => {
        const loadTime = performance.now() - startTime;
        console.log(`Images loaded in ${Math.round(loadTime)}ms`);

        container.innerHTML = html;

        // Initialize thumbnails immediately without setTimeout delay
        if (window.initializeThumbnails) {
          window.initializeThumbnails();
        } else {
          this.initializeThumbnails();
        }
      })
      .catch((error) => {
        console.error('Error loading images:', error);
        container.innerHTML = `
          <div class="alert alert-warning text-center">
            <i class="fas fa-exclamation-triangle me-2"></i>
            Unable to load images. 
            <button class="btn btn-link p-0 ms-2" onclick="window.wellModal.loadImagesTab('${wellId}')">
              Try again
            </button>
          </div>
        `;
      });
  }

  loadPxrdTab(wellId) {
    const container = document.getElementById('wellPxrdContent');

    // Show loading indicator
    container.innerHTML = `
      <div class="text-center py-4">
        <div class="spinner-border text-secondary mb-2" role="status">
          <span class="visually-hidden">Loading PXRD data...</span>
        </div>
        <div class="text-muted small">Loading PXRD patterns...</div>
      </div>
    `;

    fetch(`/wells/${wellId}/pxrd_patterns`)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.text();
      })
      .then(html => {
        container.innerHTML = html;

        // Execute any scripts that were injected
        const scripts = container.querySelectorAll('script');
        scripts.forEach(script => {
          try {
            // Use Function constructor instead of eval for better security
            new Function(script.innerHTML)();
          } catch (e) {
            console.error('Error executing PXRD script:', e);
          }
        });

        console.log('PXRD data loaded successfully for well', wellId);
      })
      .catch((error) => {
        console.error('Error loading PXRD patterns:', error);
        container.innerHTML = `
          <div class="alert alert-warning text-center">
            <i class="fas fa-exclamation-triangle me-2"></i>
            Unable to load PXRD patterns. 
            <button class="btn btn-link p-0 ms-2" onclick="window.wellModal.loadPxrdTab('${wellId}')">
              Try again
            </button>
          </div>
        `;
      });
  }

  loadScxrdTab(wellId) {
    const container = document.getElementById('wellScxrdContent');

    // Show loading indicator
    container.innerHTML = `
      <div class="text-center py-4">
        <div class="spinner-border text-secondary mb-2" role="status">
          <span class="visually-hidden">Loading SCXRD data...</span>
        </div>
        <div class="text-muted small">Loading SCXRD datasets...</div>
      </div>
    `;

    fetch(`/wells/${wellId}/scxrd_datasets`)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.text();
      })
      .then(html => {
        console.log('SCXRD: Received HTML response:', html.substring(0, 200) + '...');
        container.innerHTML = html;

        // Execute any scripts that were injected
        const scripts = container.querySelectorAll('script');
        console.log('SCXRD: Found', scripts.length, 'scripts to execute');
        scripts.forEach(script => {
          try {
            // Use Function constructor instead of eval for better security
            new Function(script.innerHTML)();
          } catch (e) {
            console.error('Error executing SCXRD script:', e);
          }
        });

        console.log('SCXRD data loaded successfully for well', wellId);
      })
      .catch((error) => {
        console.error('Error loading SCXRD datasets:', error);
        container.innerHTML = `
          <div class="alert alert-warning text-center">
            <i class="fas fa-exclamation-triangle me-2"></i>
            Unable to load SCXRD datasets. 
            <button class="btn btn-link p-0 ms-2" onclick="window.wellModal.loadScxrdTab('${wellId}')">
              Try again
            </button>
          </div>
        `;
      });
  }

  loadContentTab(wellId) {
    fetch(`/wells/${wellId}/content_form`)
      .then(response => response.text())
      .then(html => {
        document.getElementById('wellContentForm').innerHTML = html;
      })
      .catch(() => {
        document.getElementById('wellContentForm').innerHTML = '<p>Error loading content form.</p>';
      });
  }

  initializeThumbnails() {
    const thumbnails = document.querySelectorAll('.image-thumbnail');
    thumbnails.forEach((thumbnail) => {
      if (thumbnail.hasAttribute('data-initialized')) return;
      thumbnail.setAttribute('data-initialized', 'true');

      thumbnail.addEventListener('mouseenter', function () {
        const actions = this.querySelector('.image-actions');
        if (actions) actions.classList.remove('d-none');
      });

      thumbnail.addEventListener('mouseleave', function () {
        const actions = this.querySelector('.image-actions');
        if (actions) actions.classList.add('d-none');
      });

      thumbnail.addEventListener('click', function (e) {
        const imageId = this.getAttribute('data-image-id');
        const imageUrl = this.getAttribute('data-image-url');
        const largeImageUrl = this.getAttribute('data-large-image-url');
        if (imageId && imageUrl && window.showImageInMain) {
          window.showImageInMain(imageId, imageUrl, largeImageUrl);
        }
      });
    });
  }

  bindContentEvents() {
    // Event delegation for dynamically loaded content
    this.contentContainer.addEventListener('click', (event) => {
      const target = event.target;
      const action = target.getAttribute('data-action');
      const wellId = target.getAttribute('data-well-id');

      if (action === 'add-stock-solution') {
        this.addStockSolution(wellId);
      } else if (action === 'remove-stock-solution') {
        const contentId = target.getAttribute('data-content-id');
        this.removeStockSolution(wellId, contentId);
      } else if (action === 'remove-all-content') {
        this.removeAllContent(wellId);
      } else {
        // Handle stock solution selection
        const dropdownItem = target.closest('.dropdown-item');
        if (dropdownItem && dropdownItem.dataset.solutionId) {
          const id = dropdownItem.dataset.solutionId;
          const name = dropdownItem.dataset.solutionName;
          const hiddenFieldId = dropdownItem.dataset.hiddenFieldId;
          const inputId = dropdownItem.dataset.inputId;
          const resultsId = dropdownItem.dataset.resultsId;
          this.selectStockSolution(id, name, hiddenFieldId, inputId, resultsId);
        }
      }
    });

    // Event delegation for input events
    this.contentContainer.addEventListener('input', (event) => {
      const target = event.target;
      if (target.id && target.id.startsWith('stockSolutionSearch_')) {
        const wellId = target.id.replace('stockSolutionSearch_', '');
        const hiddenFieldId = `stockSolutionId_${wellId}`;
        const resultsId = `stockSolutionResults_${wellId}`;
        this.searchStockSolutions(target, hiddenFieldId, resultsId);
      }
    });

    // Event delegation for blur events
    this.contentContainer.addEventListener('blur', (event) => {
      const target = event.target;
      if (target.id && target.id.startsWith('stockSolutionSearch_')) {
        const wellId = target.id.replace('stockSolutionSearch_', '');
        const resultsId = `stockSolutionResults_${wellId}`;
        setTimeout(() => this.hideStockSolutionResults(resultsId), 200);
      }
    }, true);
  }

  async searchStockSolutions(input, hiddenFieldId, resultsId) {
    const query = input.value.trim();
    const resultsDiv = document.getElementById(resultsId);

    if (query.length < 2) {
      resultsDiv.classList.add('d-none');
      return;
    }

    try {
      const response = await fetch(`/stock_solutions/search?q=${encodeURIComponent(query)}`, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      });

      if (!response.ok) {
        throw new Error('Search failed');
      }

      const data = await response.json();
      this.displayStockSolutionResults(data, resultsId, hiddenFieldId, input);
    } catch (error) {
      console.error('Stock solution search error:', error);
      resultsDiv.innerHTML = '<div class="dropdown-item text-danger">Search failed</div>';
      resultsDiv.classList.remove('d-none');
    }
  }

  displayStockSolutionResults(results, resultsId, hiddenFieldId, input) {
    const resultsDiv = document.getElementById(resultsId);

    if (results.length === 0) {
      resultsDiv.innerHTML = '<div class="dropdown-item text-muted">No stock solutions found</div>';
    } else {
      resultsDiv.innerHTML = results.map(solution =>
        `<button type="button" class="dropdown-item" 
                 data-solution-id="${solution.id}" 
                 data-solution-name="${solution.display_name}"
                 data-hidden-field-id="${hiddenFieldId}"
                 data-input-id="${input.id}"
                 data-results-id="${resultsId}">
          <strong>${solution.display_name}</strong>
          ${solution.component_summary ? `<br><small class="text-muted">${solution.component_summary}</small>` : ''}
        </button>`
      ).join('');
    }

    resultsDiv.classList.remove('d-none');
  }

  selectStockSolution(id, name, hiddenFieldId, inputId, resultsId) {
    const hiddenField = document.getElementById(hiddenFieldId);
    const inputField = document.getElementById(inputId);

    if (hiddenField) {
      hiddenField.value = id;
    }

    if (inputField) {
      inputField.value = name;
    }

    this.hideStockSolutionResults(resultsId);
  }

  hideStockSolutionResults(resultsId) {
    const resultsDiv = document.getElementById(resultsId);
    if (resultsDiv) {
      resultsDiv.classList.add('d-none');
    }
  }

  addStockSolution(wellId) {
    const hiddenInput = document.getElementById(`stockSolutionId_${wellId}`);
    const searchInput = document.getElementById(`stockSolutionSearch_${wellId}`);
    const volumeInput = document.getElementById(`volumeAmountInput_${wellId}`);

    const stockSolutionId = hiddenInput.value;
    const volumeWithUnit = volumeInput.value.trim();

    if (!stockSolutionId) {
      this.showMessage(wellId, 'Please select a stock solution', 'danger');
      return;
    }

    if (!volumeWithUnit) {
      this.showMessage(wellId, 'Please enter a volume with unit (e.g., 50 μL)', 'danger');
      return;
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]');

    if (!csrfToken) {
      this.showMessage(wellId, 'CSRF token not found', 'danger');
      return;
    }

    fetch(`/wells/${wellId}/well_contents`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken.getAttribute('content')
      },
      body: JSON.stringify({
        well_content: {
          stock_solution_id: stockSolutionId,
          volume_with_unit: volumeWithUnit
        }
      })
    })
      .then(response => response.json())
      .then(data => {
        if (data.status === 'success') {
          this.showMessage(wellId, data.message, 'success');
          // Reload the content form
          this.reloadContentForm(wellId);
          // Reset the form
          hiddenInput.value = '';
          searchInput.value = '';
          volumeInput.value = '';
        } else {
          this.showMessage(wellId, data.message, 'danger');
        }
      })
      .catch(error => {
        console.error('Error:', error);
        this.showMessage(wellId, 'Error adding stock solution: ' + error.message, 'danger');
      });
  }

  removeStockSolution(wellId, contentId) {
    if (!confirm('Are you sure you want to remove this stock solution from the well?')) {
      return;
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]');

    fetch(`/wells/${wellId}/well_contents/${contentId}`, {
      method: 'DELETE',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken.getAttribute('content')
      }
    })
      .then(response => response.json())
      .then(data => {
        if (data.status === 'success') {
          this.showMessage(wellId, data.message, 'success');
          // Reload the content form
          this.reloadContentForm(wellId);
        } else {
          this.showMessage(wellId, data.message, 'danger');
        }
      })
      .catch(error => {
        console.error('Error:', error);
        this.showMessage(wellId, 'Error removing stock solution', 'danger');
      });
  }

  removeAllContent(wellId) {
    if (!confirm('Are you sure you want to remove all stock solutions from this well?')) {
      return;
    }

    const csrfToken = document.querySelector('meta[name="csrf-token"]');

    fetch(`/wells/${wellId}/update_content`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': csrfToken.getAttribute('content')
      },
      body: JSON.stringify({
        remove_all_content: true
      })
    })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          this.showMessage(wellId, data.message, 'success');
          // Reload the content form
          this.reloadContentForm(wellId);
        } else {
          this.showMessage(wellId, data.message, 'danger');
        }
      })
      .catch(error => {
        console.error('Error:', error);
        this.showMessage(wellId, 'Error removing content', 'danger');
      });
  }

  reloadContentForm(wellId) {
    fetch(`/wells/${wellId}/content_form`)
      .then(response => response.text())
      .then(html => {
        document.getElementById('wellContentForm').innerHTML = html;
      })
      .catch(error => {
        console.error('Error reloading form:', error);
      });
  }

  showMessage(wellId, message, type) {
    const messagesDiv = document.getElementById(`contentMessages_${wellId}`);
    if (!messagesDiv) {
      console.error('Messages div not found for well:', wellId);
      return;
    }

    messagesDiv.innerHTML = `
      <div class="alert alert-${type} alert-dismissible fade show" role="alert">
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
      </div>
    `;

    // Auto-hide after 3 seconds
    setTimeout(() => {
      const alert = messagesDiv.querySelector('.alert');
      if (alert) {
        alert.classList.remove('show');
        setTimeout(() => {
          messagesDiv.innerHTML = '';
        }, 150);
      }
    }, 3000);
  }
}

// Keyboard shortcut management
class KeyboardShortcuts {
  constructor() {
    this.init();
  }

  init() {
    this.boundHandleKeydown = (e) => this.handleKeydown(e);
    document.addEventListener('keydown', this.boundHandleKeydown);
  }

  destroy() {
    if (this.boundHandleKeydown) {
      document.removeEventListener('keydown', this.boundHandleKeydown);
    }
  }

  handleKeydown(e) {
    // Don't trigger shortcuts when typing in input fields
    if (e.target.matches('input, textarea, select')) {
      return;
    }

    // Handle shortcuts based on key pressed
    switch (e.key.toLowerCase()) {
      case CONSTANTS.SHORTCUTS.TOGGLE_SELECT_MODE:
        e.preventDefault();
        this.toggleSelectMode();
        break;

      case CONSTANTS.SHORTCUTS.EDIT_SELECTED:
        if (window.wellSelector?.selectedWells?.size > 0) {
          e.preventDefault();
          window.wellSelector.openBulkEditModal();
        }
        break;

      case CONSTANTS.SHORTCUTS.CLEAR_SELECTION:
        if (window.wellSelector?.selectMode) {
          e.preventDefault();
          this.clearSelection();
        }
        break;

      case CONSTANTS.SHORTCUTS.ESCAPE:
        this.handleEscape();
        break;
    }
  }

  toggleSelectMode() {
    const selectSwitch = document.getElementById('selectModeSwitch');
    if (selectSwitch) {
      selectSwitch.checked = !selectSwitch.checked;
      selectSwitch.dispatchEvent(new Event('change'));

      // Show user feedback
      const mode = selectSwitch.checked ? 'enabled' : 'disabled';
      this.showShortcutFeedback(`Multi-select mode ${mode}`);
    }
  }

  clearSelection() {
    if (window.wellSelector) {
      window.wellSelector.selectedWells.clear();
      document.querySelectorAll('.well-select-btn.border-info').forEach(btn => {
        btn.classList.remove('border-info', 'shadow');
      });
      window.wellSelector.updateEditButton();
      this.showShortcutFeedback('Selection cleared');
    }
  }

  handleEscape() {
    // Close any open modals
    const modals = document.querySelectorAll('.modal.show');
    modals.forEach(modal => {
      const bsModal = bootstrap.Modal.getInstance(modal);
      if (bsModal) {
        bsModal.hide();
      }
    });

    // Clear selection if in select mode
    if (window.wellSelector?.selectMode) {
      this.clearSelection();
    }
  }

  showShortcutFeedback(message) {
    // Create temporary toast for shortcut feedback
    const toast = document.createElement('div');
    toast.className = 'toast show position-fixed top-0 start-50 translate-middle-x mt-3';
    toast.style.zIndex = '1060';
    toast.innerHTML = `
      <div class="toast-body bg-dark text-white rounded">
        <small>${message}</small>
      </div>
    `;

    document.body.appendChild(toast);

    setTimeout(() => {
      toast.remove();
    }, 1500);
  }
}

// Initialize everything when page loads (including Turbo navigation)
document.addEventListener('turbo:load', () => {
  // Only initialize if we're on the plates show page and not already initialized
  if (document.querySelector('#well-grid-container') && !window.wellSelector) {
    console.log('Initializing plates_show components...');
    
    try {
      window.keyboardShortcuts = new KeyboardShortcuts();
      console.log('KeyboardShortcuts initialized');
      
      window.wellSelector = new WellSelector();
      console.log('WellSelector initialized');
      
      window.wellModal = new WellModal();
      console.log('WellModal initialized');
    } catch (error) {
      console.error('Error initializing plates_show components:', error);
    }
  }
});

// Clean up before page is cached by Turbo
document.addEventListener('turbo:before-cache', () => {
  // Clean up global references and document-level event listeners
  if (window.keyboardShortcuts && window.keyboardShortcuts.destroy) {
    window.keyboardShortcuts.destroy();
  }
  window.keyboardShortcuts = null;
  window.wellSelector = null;
  window.wellModal = null;
});

// Fallback for direct page loads (non-Turbo)
document.addEventListener('DOMContentLoaded', () => {
  // Only initialize if not already done by turbo:load
  if (document.querySelector('#well-grid-container') && !window.wellSelector) {
    console.log('Initializing plates_show components via DOMContentLoaded...');
    
    try {
      window.keyboardShortcuts = new KeyboardShortcuts();
      console.log('KeyboardShortcuts initialized');
      
      window.wellSelector = new WellSelector();
      console.log('WellSelector initialized');
      
      window.wellModal = new WellModal();
      console.log('WellModal initialized');
    } catch (error) {
      console.error('Error initializing plates_show components:', error);
    }
  }
});
