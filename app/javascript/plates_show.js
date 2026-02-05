// Plates Show Page JavaScript
// Enhanced with error handling, performance optimizations, and better structure

import * as bootstrap from "bootstrap";

'use strict';

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
    const modalEl = document.getElementById('editMultipleWellsModal');
    if (!modalEl) {
      console.error('Bulk edit modal not found in DOM. Please add it to your view template.');
      return;
    }
    const modal = new bootstrap.Modal(modalEl);
    modal.show();

    // Attach event listeners when modal is shown
    modalEl.addEventListener('shown.bs.modal', () => {
      this.setupBulkEditModal(wellIds);
    }, { once: true });
  }

  setupBulkEditModal(wellIds) {
    // Set well IDs as a custom event that the Stimulus controller can listen for
    const modalEl = document.getElementById('editMultipleWellsModal');
    if (!modalEl) return;

    // Store well IDs as data attribute for the Stimulus controller to access
    modalEl.dataset.wellIds = JSON.stringify(wellIds);

    // Dispatch a custom event to notify the controller
    const event = new CustomEvent('wellIdsSet', {
      detail: { wellIds: wellIds },
      bubbles: true
    });
    modalEl.dispatchEvent(event);

    // The Stimulus controller will handle all the UI logic now
  }
}

// Well modal functionality
class WellModal {
  constructor() {
    this.modal = document.getElementById('wellImagesModal');
    this.contentContainer = document.getElementById('wellContentForm');
    this.currentWellId = null;
    this.contentLoaded = false;
    this.pxrdLoaded = false;
    this.scxrdLoaded = false;
    this.init();
  }

  init() {
    if (!this.modal) return;

    this.modal.addEventListener('show.bs.modal', (event) => {
      this.handleModalShow(event);
    });

    this.modal.addEventListener('hidden.bs.modal', () => {
      this.handleModalHidden();
    });

    // Add tab click listeners for lazy loading (fallback if background loading fails)
    const contentTab = document.getElementById('content-tab');
    if (contentTab) {
      contentTab.addEventListener('click', () => {
        if (this.currentWellId && !this.contentLoaded) {
          this.loadContentTab(this.currentWellId);
        }
      });
    }

    const pxrdTab = document.getElementById('pxrd-tab');
    if (pxrdTab) {
      pxrdTab.addEventListener('click', () => {
        if (this.currentWellId && !this.pxrdLoaded) {
          this.loadPxrdTab(this.currentWellId);
        }
      });
    }

    const scxrdTab = document.getElementById('scxrd-tab');
    if (scxrdTab) {
      scxrdTab.addEventListener('click', () => {
        if (this.currentWellId && !this.scxrdLoaded) {
          this.loadScxrdTab(this.currentWellId);
        }
      });
    }

    if (this.contentContainer) {
      this.bindContentEvents();
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
    this.contentLoaded = false;

    // Update modal title immediately
    document.getElementById('wellImagesModalLabel').textContent = `Well ${wellLabel} Details`;

    // Ensure Content tab is active when modal opens
    this.activateContentTab();

    // Show immediate loading state for images tab only
    document.getElementById('wellImagesContent').innerHTML = `
      <div class="text-center py-3">
        <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
          <span class="visually-hidden">Loading images...</span>
        </div>
        <div class="text-muted small">Loading images...</div>
      </div>
    `;

    // Load images tab immediately (priority)
    setTimeout(() => this.loadImagesTab(wellId), 0);

    // Show ready-to-load placeholders for other tabs
    document.getElementById('wellContentForm').innerHTML = `
      <div class="text-center py-4 text-muted">
        <i class="fas fa-flask fa-2x mb-2"></i>
        <div>Stock Solutions</div>
        <small class="text-muted">Loading in background...</small>
      </div>
    `;

    document.getElementById('wellPxrdContent').innerHTML = `
      <div class="text-center py-4 text-muted">
        <i class="fas fa-chart-line fa-2x mb-2"></i>
        <div>PXRD Patterns</div>
        <small class="text-muted">Loading in background...</small>
      </div>
    `;

    document.getElementById('wellScxrdContent').innerHTML = `
      <div class="text-center py-4 text-muted">
        <i class="fas fa-cube fa-2x mb-2"></i>
        <div>SCXRD Datasets</div>
        <small class="text-muted">Loading in background...</small>
      </div>
    `;

    // Load other tabs in background with staggered delays
    // Note: SCXRD is NOT loaded in background to prevent CifVis animation issues
    // Disabled - now using Stimulus controller for modal management
    // setTimeout(() => this.loadContentTabInBackground(wellId), 200);
    // setTimeout(() => this.loadPxrdTabInBackground(wellId), 400);
    // SCXRD will be loaded only when the tab is clicked
  }

  handleModalHidden() {
    console.log('Well modal hidden - cleaning up visualizations');

    // Clean up any CifVis instances within the modal
    this.cleanupModalVisualizations();

    // Reset tab indicators when modal is closed
    const contentTab = document.getElementById('content-tab');
    const pxrdTab = document.getElementById('pxrd-tab');
    const scxrdTab = document.getElementById('scxrd-tab');

    if (contentTab) contentTab.innerHTML = 'Stock Solutions';
    if (pxrdTab) pxrdTab.innerHTML = 'PXRD';
    if (scxrdTab) scxrdTab.innerHTML = 'SCXRD';

    // Clear content containers to stop any running visualizations
    const containers = [
      'wellImagesContent',
      'wellContentForm',
      'wellPxrdContent',
      'wellScxrdContent'
    ];

    containers.forEach(containerId => {
      const container = document.getElementById(containerId);
      if (container) {
        container.innerHTML = '';
      }
    });

    // Reset loaded flags for next modal opening
    this.currentWellId = null;
    this.contentLoaded = false;
    this.pxrdLoaded = false;
    this.scxrdLoaded = false;
  }

  cleanupModalVisualizations() {
    // Clean up CifVis widgets specifically within the modal
    const modalElement = document.getElementById('wellImagesModal');
    if (modalElement) {
      const cifWidgets = modalElement.querySelectorAll('cifview-widget');
      cifWidgets.forEach((widget, index) => {
        try {
          console.log(`Cleaning up modal cifview-widget ${index + 1}`);

          if (widget._cifvis) {
            if (typeof widget._cifvis.destroy === 'function') {
              widget._cifvis.destroy();
            } else if (typeof widget._cifvis.dispose === 'function') {
              widget._cifvis.dispose();
            }
          }

          // Clear any animation references
          if (widget._animation) {
            widget._animation = null;
          }

          if (widget.parentNode) {
            widget.parentNode.removeChild(widget);
          }
        } catch (error) {
          console.warn(`Error cleaning up modal cifview-widget ${index + 1}:`, error);
        }
      });
    }

    // Clean up SCXRD diffraction viewers within the modal
    Object.keys(window).forEach(key => {
      if (key.startsWith('scxrdViewer_') && window[key]) {
        try {
          const viewer = window[key];
          // Check if this viewer's container is within the modal
          const container = document.getElementById(viewer.containerId);
          if (container && modalElement && modalElement.contains(container)) {
            console.log(`Cleaning up modal SCXRD viewer: ${key}`);
            if (typeof viewer.destroy === 'function') {
              viewer.destroy();
            }
            delete window[key];
          }
        } catch (error) {
          console.warn(`Error cleaning up modal SCXRD viewer ${key}:`, error);
        }
      }
    });

    // Use the global cleanup manager if available
    if (window.turboCleanupManager) {
      window.turboCleanupManager.cleanupCifVisWidgets();
      window.turboCleanupManager.cleanupScxrdViewers();
    }
  }

  activateContentTab() {
    // Ensure Content tab is active
    const contentTab = document.getElementById('content-tab');
    const contentPane = document.getElementById('content');
    const allTabs = document.querySelectorAll('#wellTabs .nav-link');
    const allPanes = document.querySelectorAll('#wellTabContent .tab-pane');

    // Remove active class from all tabs and panes
    allTabs.forEach(tab => {
      tab.classList.remove('active');
      tab.setAttribute('aria-selected', 'false');
    });
    allPanes.forEach(pane => {
      pane.classList.remove('show', 'active');
    });

    // Activate content tab
    if (contentTab && contentPane) {
      contentTab.classList.add('active');
      contentTab.setAttribute('aria-selected', 'true');
      contentPane.classList.add('show', 'active');
    }
  }

  loadContentTabInBackground(wellId) {
    // Disabled - now using Stimulus controller for modal management
    console.log('loadContentTabInBackground called (disabled), wellId:', wellId);
    // if (this.contentLoaded) return;

    // fetch(`/wells/${wellId}/content_form`)
    //   .then(response => response.text())
    //   .then(html => {
    //     document.getElementById('wellContentForm').innerHTML = html;
    //     this.contentLoaded = true;
    //     
    //     // Content loaded in background - no visual indicator needed
    //   })
    //   .catch(() => {
    //     document.getElementById('wellContentForm').innerHTML = `
    //       <div class="text-center py-4 text-muted">
    //         <i class="fas fa-exclamation-triangle fa-2x mb-2 text-warning"></i>
    //         <div>Error loading stock solutions</div>
    //         <button class="btn btn-link btn-sm" onclick="window.wellModal.loadContentTab('${wellId}')">
    //           Try again
    //         </button>
    //       </div>
    //     `;
    //   });
  }

  loadPxrdTabInBackground(wellId) {
    if (this.pxrdLoaded) return;

    fetch(`/wells/${wellId}/pxrd_patterns`)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.text();
      })
      .then(html => {
        document.getElementById('wellPxrdContent').innerHTML = html;
        this.pxrdLoaded = true;

        // Execute any scripts that were injected
        const scripts = document.querySelectorAll('#wellPxrdContent script');
        scripts.forEach(script => {
          try {
            if (script.type === 'module') {
              const moduleScript = document.createElement('script');
              moduleScript.type = 'module';
              moduleScript.textContent = script.innerHTML;
              document.head.appendChild(moduleScript);
              setTimeout(() => moduleScript.remove(), 100);
            } else {
              new Function(script.innerHTML)();
            }
          } catch (e) {
            console.error('Error executing PXRD script:', e);
          }
        });

        // PXRD loaded in background - no visual indicator needed
      })
      .catch((error) => {
        console.error('Error loading PXRD patterns:', error);
        document.getElementById('wellPxrdContent').innerHTML = `
          <div class="text-center py-4 text-muted">
            <i class="fas fa-exclamation-triangle fa-2x mb-2 text-warning"></i>
            <div>Error loading PXRD patterns</div>
            <button class="btn btn-link btn-sm" onclick="window.wellModal.loadPxrdTab('${wellId}')">
              Try again
            </button>
          </div>
        `;
      });
  }

  loadScxrdTabInBackground(wellId) {
    if (this.scxrdLoaded) return;

    fetch(`/wells/${wellId}/scxrd_datasets`)
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP ${response.status}`);
        }
        return response.text();
      })
      .then(html => {
        document.getElementById('wellScxrdContent').innerHTML = html;
        this.scxrdLoaded = true;

        // Execute any scripts that were injected
        const scripts = document.querySelectorAll('#wellScxrdContent script');
        scripts.forEach(script => {
          try {
            new Function(script.innerHTML)();
          } catch (e) {
            console.error('Error executing SCXRD script:', e);
          }
        });

        // SCXRD loaded in background - no visual indicator needed
      })
      .catch((error) => {
        console.error('Error loading SCXRD datasets:', error);
        document.getElementById('wellScxrdContent').innerHTML = `
          <div class="text-center py-4 text-muted">
            <i class="fas fa-exclamation-triangle fa-2x mb-2 text-warning"></i>
            <div>Error loading SCXRD datasets</div>
            <button class="btn btn-link btn-sm" onclick="window.wellModal.loadScxrdTab('${wellId}')">
              Try again
            </button>
          </div>
        `;
      });
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
        this.pxrdLoaded = true;

        // Execute any scripts that were injected
        const scripts = container.querySelectorAll('script');
        scripts.forEach(script => {
          try {
            if (script.type === 'module') {
              // Handle ES module scripts by creating a new script element
              const moduleScript = document.createElement('script');
              moduleScript.type = 'module';
              moduleScript.textContent = script.innerHTML;
              document.head.appendChild(moduleScript);
              // Clean up after execution
              setTimeout(() => moduleScript.remove(), 100);
            } else {
              // Use Function constructor for regular scripts
              new Function(script.innerHTML)();
            }
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
        this.scxrdLoaded = true;

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
    const container = document.getElementById('wellContentForm');

    // Show loading indicator
    container.innerHTML = `
      <div class="text-center py-3">
        <div class="spinner-border spinner-border-sm text-secondary mb-2" role="status">
          <span class="visually-hidden">Loading content...</span>
        </div>
        <div class="text-muted small">Loading content...</div>
      </div>
    `;

    fetch(`/wells/${wellId}/content_form`)
      .then(response => response.text())
      .then(html => {
        container.innerHTML = html;
        this.contentLoaded = true;
      })
      .catch(() => {
        container.innerHTML = `
          <div class="alert alert-warning text-center">
            <i class="fas fa-exclamation-triangle me-2"></i>
            Unable to load content form. 
            <button class="btn btn-link p-0 ms-2" onclick="window.wellModal.loadContentTab('${wellId}')">
              Try again
            </button>
          </div>
        `;
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
          amount_with_unit: volumeWithUnit
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

// G6 Unit Cell Comparison Functions
window.currentDatasetId = null;

window.loadG6Comparison = function (datasetId) {
  window.currentDatasetId = datasetId;
  const tolerance = document.getElementById('g6Tolerance').value;

  // Show loading state
  document.getElementById('g6ComparisonContent').innerHTML = `
    <div class="text-center py-4">
      <div class="spinner-border" role="status">
        <span class="visually-hidden">Loading...</span>
      </div>
      <p class="mt-2">Searching for similar unit cells...</p>
    </div>
  `;

  // Fetch comparison data
  fetch(`/scxrd_datasets/${datasetId}/g6_similar?tolerance=${tolerance}`)
    .then(response => response.json())
    .then(data => {
      displayG6Results(data);
    })
    .catch(error => {
      console.error('Error:', error);
      document.getElementById('g6ComparisonContent').innerHTML = `
        <div class="alert alert-danger">
          <i class="bi bi-exclamation-triangle me-2"></i>
          Error loading comparison data: ${error.message}
        </div>
      `;
    });
}

window.updateG6Comparison = function () {
  if (window.currentDatasetId) {
    window.loadG6Comparison(window.currentDatasetId);
  }
}

window.displayG6Results = function (data) {
  const content = document.getElementById('g6ComparisonContent');

  if (!data.success) {
    content.innerHTML = `
      <div class="alert alert-warning">
        <i class="bi bi-info-circle me-2"></i>
        ${data.error}
      </div>
    `;
    return;
  }

  if (data.count === 0) {
    content.innerHTML = `
      <div class="alert alert-info">
        <i class="bi bi-search me-2"></i>
        No similar unit cells found within G6 distance of ${data.tolerance}.
        <hr>
        <small class="text-muted">
          <strong>Current dataset:</strong> ${data.current_dataset.experiment_name}<br>
          <strong>Unit cell:</strong> ${data.current_dataset.unit_cell ?
        `${data.current_dataset.unit_cell.bravais || 'P'} a=${data.current_dataset.unit_cell.a}Å b=${data.current_dataset.unit_cell.b}Å c=${data.current_dataset.unit_cell.c}Å α=${data.current_dataset.unit_cell.alpha}° β=${data.current_dataset.unit_cell.beta}° γ=${data.current_dataset.unit_cell.gamma}°` :
        'No unit cell'}
        </small>
      </div>
    `;
    return;
  }

  let html = `
    <div class="alert alert-success">
      <i class="bi bi-check-circle me-2"></i>
      Found <strong>${data.count}</strong> dataset(s) with similar unit cells (G6 distance ≤ ${data.tolerance})
    </div>
    
    <div class="mb-3">
      <small class="text-muted">
        <strong>Reference dataset:</strong> ${data.current_dataset.experiment_name}<br>
        <strong>Unit cell:</strong> ${data.current_dataset.unit_cell ?
      `${data.current_dataset.unit_cell.bravais || 'P'} a=${data.current_dataset.unit_cell.a}Å b=${data.current_dataset.unit_cell.b}Å c=${data.current_dataset.unit_cell.c}Å α=${data.current_dataset.unit_cell.alpha}° β=${data.current_dataset.unit_cell.beta}° γ=${data.current_dataset.unit_cell.gamma}°` :
      'No unit cell'}
      </small>
    </div>

    <div class="table-responsive">
      <table class="table table-sm">
        <thead>
          <tr>
            <th>Dataset</th>
            <th>Unit Cell</th>
            <th>G6 Distance</th>
            <th>Location</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
  `;

  data.datasets.forEach(dataset => {
    const unitCellText = dataset.unit_cell ?
      `${dataset.unit_cell.bravais} a=${dataset.unit_cell.a}Å b=${dataset.unit_cell.b}Å c=${dataset.unit_cell.c}Å α=${dataset.unit_cell.alpha}° β=${dataset.unit_cell.beta}° γ=${dataset.unit_cell.gamma}°` :
      'No unit cell';

    const locationText = dataset.well ?
      `${dataset.well.plate_barcode}-${dataset.well.label}` :
      'Standalone';

    html += `
      <tr>
        <td>
          <strong>${dataset.experiment_name}</strong><br>
          <small class="text-muted">${dataset.measured_at}</small>
        </td>
        <td><small>${unitCellText}</small></td>
        <td><span class="badge bg-info">${dataset.g6_distance}</span></td>
        <td><small>${locationText}</small></td>
        <td>
          <a href="/scxrd_datasets/${dataset.id}" class="btn btn-outline-primary btn-sm" target="_blank">
            <i class="bi bi-eye"></i> View
          </a>
        </td>
      </tr>
    `;
  });

  html += `
        </tbody>
      </table>
    </div>
  `;

  content.innerHTML = html;
}

// Bridge between old system and new Stimulus controller
window.wellModal = {
  // Add a test function for debugging
  test: function (wellId = 1) {
    console.log('Testing well modal with wellId:', wellId);
    this.showModal(wellId, 'content');
  },

  loadContentTab: function (wellId) {
    console.log('loadContentTab called with wellId:', wellId, 'type:', typeof wellId);
    this.showModal(wellId, 'content');
  },

  loadImagesTab: function (wellId) {
    this.showModal(wellId, 'images');
  },

  loadPxrdTab: function (wellId) {
    this.showModal(wellId, 'pxrd');
  },

  loadScxrdTab: function (wellId) {
    this.showModal(wellId, 'scxrd');
  },

  showModal: function (wellId, activeTab = 'content') {
    console.log('showModal called with wellId:', wellId, 'activeTab:', activeTab);

    // Get the well information
    const wellElement = document.querySelector(`[data-well-id="${wellId}"]`);
    let wellLabel = '';

    if (wellElement) {
      wellLabel = wellElement.dataset.wellLabel ||
        wellElement.dataset.wellRow + wellElement.dataset.wellColumn ||
        `Well ${wellId}`;
    } else {
      wellLabel = `Well ${wellId}`;
    }

    console.log('Well label determined as:', wellLabel);

    // Get the modal element
    const modalElement = document.getElementById('wellImagesModal');
    if (!modalElement) {
      console.error('Modal element not found');
      return;
    }

    // Try to get the Stimulus controller
    let controller = null;
    if (window.Stimulus && window.Stimulus.application) {
      controller = window.Stimulus.application.getControllerForElementAndIdentifier(modalElement, 'well-modal');
    }

    if (controller) {
      console.log('Using Stimulus controller');

      // Ensure wellId is a valid number
      const parsedWellId = parseInt(wellId);
      console.log('Original wellId:', wellId, 'parsed:', parsedWellId);

      if (isNaN(parsedWellId) || parsedWellId <= 0) {
        console.error('Invalid well ID provided:', wellId);
        return;
      }

      // Set the values on the controller BEFORE showing the modal
      controller.wellIdValue = parsedWellId;
      controller.wellLabelValue = wellLabel;

      console.log('Set controller values:', {
        wellId: controller.wellIdValue,
        wellLabel: controller.wellLabelValue
      });

      // Show modal
      const modal = new bootstrap.Modal(modalElement);
      modal.show();

      // Set active tab after modal is shown
      if (activeTab !== 'content') {
        setTimeout(() => {
          this.activateTab(activeTab);
        }, 200);
      }
    } else {
      // Fallback to direct DOM manipulation
      console.log('Stimulus controller not found, using fallback');
      this.fallbackShowModal(wellId, wellLabel, activeTab);
    }
  },

  activateTab: function (tabName) {
    const tab = document.getElementById(`${tabName}-tab`);
    if (tab) {
      // Activate the tab using Bootstrap
      const tabTrigger = new bootstrap.Tab(tab);
      tabTrigger.show();
    }
  },

  fallbackShowModal: function (wellId, wellLabel, activeTab) {
    console.log('fallbackShowModal called with:', wellId, wellLabel, activeTab);

    // Update title
    const titleElement = document.getElementById('wellImagesModalLabel');
    if (titleElement) {
      titleElement.textContent = `Well ${wellLabel} Details`;
      console.log('Title updated to:', titleElement.textContent);
    }

    // Show modal first
    const modalElement = document.getElementById('wellImagesModal');
    const modal = new bootstrap.Modal(modalElement);
    modal.show();

    // Wait for modal to be shown, then activate tab and load content
    modalElement.addEventListener('shown.bs.modal', () => {
      console.log('Modal shown event fired');

      // Activate the correct tab
      if (activeTab === 'content' || !activeTab) {
        console.log('Activating content tab');
        this.activateContentTab();
        this.fallbackLoadContent(wellId);
      } else {
        console.log('Activating tab:', activeTab);
        this.activateTab(activeTab);

        // Load content for other tabs if needed
        if (activeTab === 'images') {
          this.fallbackLoadImages(wellId);
        }
      }
    }, { once: true }); // Use once: true to prevent multiple event listeners
  },

  activateContentTab: function () {
    console.log('activateContentTab called');
    const contentTab = document.getElementById('content-tab');
    const contentPane = document.getElementById('content');
    const allTabs = document.querySelectorAll('#wellTabs .nav-link');
    const allPanes = document.querySelectorAll('#wellTabContent .tab-pane');

    console.log('Found elements:', {
      contentTab: !!contentTab,
      contentPane: !!contentPane,
      allTabsCount: allTabs.length,
      allPanesCount: allPanes.length
    });

    // Remove active class from all tabs and panes
    allTabs.forEach(tab => {
      tab.classList.remove('active');
      tab.setAttribute('aria-selected', 'false');
    });
    allPanes.forEach(pane => {
      pane.classList.remove('show', 'active');
    });

    // Activate content tab
    if (contentTab && contentPane) {
      contentTab.classList.add('active');
      contentTab.setAttribute('aria-selected', 'true');
      contentPane.classList.add('show', 'active');
      console.log('Content tab activated successfully');
    } else {
      console.error('Content tab or pane not found');
    }
  },

  fallbackLoadContent: function (wellId) {
    console.log('fallbackLoadContent called for wellId:', wellId);
    const contentDiv = document.getElementById('wellContentForm');
    if (contentDiv && wellId) {
      console.log('Loading content for well', wellId);
      contentDiv.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading content...</span>
          </div>
          <div class="text-muted">Loading well contents...</div>
        </div>
      `;

      fetch(`/wells/${wellId}/content_form`)
        .then(response => {
          console.log('Content form response status:', response.status);
          return response.text();
        })
        .then(html => {
          console.log('Content loaded successfully');
          contentDiv.innerHTML = html;
        })
        .catch(error => {
          console.error('Failed to load content:', error);
          contentDiv.innerHTML = `
            <div class="alert alert-danger">
              Failed to load well contents. Please try again.
            </div>
          `;
        });
    } else {
      console.error('Content div not found or wellId missing:', { contentDiv, wellId });
    }
  },

  fallbackLoadImages: function (wellId) {
    console.log('fallbackLoadImages called for wellId:', wellId);
    const imagesDiv = document.getElementById('wellImagesContent');
    if (imagesDiv && wellId) {
      imagesDiv.innerHTML = `
        <div class="text-center py-3">
          <div class="spinner-border spinner-border-sm text-primary mb-2" role="status">
            <span class="visually-hidden">Loading images...</span>
          </div>
          <div class="text-muted">Loading well images...</div>
        </div>
      `;

      fetch(`/wells/${wellId}/images`)
        .then(response => response.text())
        .then(html => {
          imagesDiv.innerHTML = html;
        })
        .catch(error => {
          console.error('Failed to load images:', error);
          imagesDiv.innerHTML = `
            <div class="alert alert-warning">
              Failed to load images. Please refresh and try again.
            </div>
          `;
        });
    }
  }
};

// Initialize everything when DOM is ready
function initializePlatesShow() {
  window.wellSelector = new WellSelector();
  // wellModal is now initialized above as a bridge object
}

// Export for use in other modules
export { WellSelector, Utils, ImageManager, CONSTANTS };

// Export initialization function for manual control
export default initializePlatesShow;
