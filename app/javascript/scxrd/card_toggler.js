// Card Toggle Functionality
class ScxrdCardToggler {
  constructor() {
    this.maxMaximizedCards = 3;
    this.datasetInstances = new Map(); // Map of dataset ID -> instance data
    this.initializeToggleHandlers();
  }

  initializeToggleHandlers() {
    // Wait for DOM to be ready (Turbo compatible)
    document.addEventListener('turbo:load', () => {
      this.setupCardToggles();
    });
    
    // Fallback for direct page loads
    document.addEventListener('DOMContentLoaded', () => {
      this.setupCardToggles();
    });

    // Also setup immediately in case DOM is already ready
    if (document.readyState !== 'loading') {
      this.setupCardToggles();
    }
  }

  // Public method to reinitialize when new content is loaded
  reinitialize() {
    console.log('Reinitializing SCXRD card toggler');
    this.datasetInstances.clear();
    this.setupCardToggles();
  }

  // Public method to reinitialize for a specific container
  reinitializeForContainer(container) {
    if (!container) return;
    console.log('Reinitializing SCXRD card toggler for container:', container);

    const datasetId = container.getAttribute('data-dataset-id');
    const datasetIndex = container.getAttribute('data-index');
    const instanceKey = `${datasetId}-${datasetIndex}`;

    // Initialize instance data for this dataset
    if (!this.datasetInstances.has(instanceKey)) {
      this.datasetInstances.set(instanceKey, {
        maximizedHistory: [],
        container: container
      });
    }

    const cardContainers = container.querySelectorAll('[data-card-id]');
    cardContainers.forEach(cardContainer => {
      const header = cardContainer.querySelector('.card-header');
      const cardId = cardContainer.getAttribute('data-card-id');

      if (header && !header.classList.contains('toggle-initialized')) {
        header.style.cursor = 'pointer';
        header.style.userSelect = 'none';
        header.addEventListener('click', () => this.toggleCard(cardId, instanceKey));

        // Add visual indication that it's clickable
        header.innerHTML += ' <i class="fas fa-chevron-up toggle-icon ms-1" style="font-size: 0.8em; transition: transform 0.3s ease;"></i>';

        // Mark as initialized to avoid duplicate handlers
        header.classList.add('toggle-initialized');
      }
    });

    // Initialize default states for this container
    this.initializeDefaultStatesForContainer(container, instanceKey);
  }

  initializeDefaultStatesForContainer(container, instanceKey) {
    const instanceData = this.datasetInstances.get(instanceKey);
    if (!instanceData) return;

    const allCards = container.querySelectorAll('[data-card-id]');
    allCards.forEach((cardElement, index) => {
      const cardId = cardElement.getAttribute('data-card-id');
      if (index < 3 && !cardElement.classList.contains('minimized')) {
        // Add to maximized history for the first 3 cards
        if (!instanceData.maximizedHistory.includes(cardId)) {
          instanceData.maximizedHistory.push(cardId);
        }
      } else if (cardElement.classList.contains('minimized')) {
        // Ensure minimized cards have the right styling
        this.applyMinimizedStyling(cardElement);
      }
    });
  }

  setupCardToggles() {
    // Find all dataset viewers and initialize them separately
    const datasetViewers = document.querySelectorAll('.scxrd-dataset-viewer');
    datasetViewers.forEach(viewer => {
      const datasetId = viewer.getAttribute('data-dataset-id');
      const datasetIndex = viewer.getAttribute('data-index');
      const instanceKey = `${datasetId}-${datasetIndex}`;

      // Initialize instance data for this dataset
      if (!this.datasetInstances.has(instanceKey)) {
        this.datasetInstances.set(instanceKey, {
          maximizedHistory: [],
          container: viewer
        });
      }

      const cardContainers = viewer.querySelectorAll('[data-card-id]');
      cardContainers.forEach(container => {
        const header = container.querySelector('.card-header');
        const cardId = container.getAttribute('data-card-id');

        if (header && !header.classList.contains('toggle-initialized')) {
          header.style.cursor = 'pointer';
          header.style.userSelect = 'none';
          header.addEventListener('click', () => this.toggleCard(cardId, instanceKey));

          // Add visual indication that it's clickable
          header.innerHTML += ' <i class="fas fa-chevron-up toggle-icon ms-1" style="font-size: 0.8em; transition: transform 0.3s ease;"></i>';

          // Mark as initialized to avoid duplicate handlers
          header.classList.add('toggle-initialized');
        }
      });

      // Initialize default states for this dataset
      this.initializeDefaultStatesForContainer(viewer, instanceKey);
    });
  }

  // This method is no longer needed as initialization is handled per container
  // initializeDefaultStates() {
  //   // Initialization is now handled per dataset in setupCardToggles()
  // }

  applyMinimizedStyling(container) {
    const headerText = container.querySelector('.card-header small');
    const toggleIcon = container.querySelector('.toggle-icon');

    if (headerText) {
      headerText.classList.add('minimized-text');
    }
    if (toggleIcon) {
      toggleIcon.style.transform = 'rotate(180deg)';
    }
  }

  toggleCard(cardId, instanceKey) {
    const container = document.querySelector(`[data-card-id="${cardId}"]`);
    if (!container) return;

    const isMinimized = container.classList.contains('minimized');

    if (isMinimized) {
      this.maximizeCard(container, cardId, instanceKey);
    } else {
      this.minimizeCard(container, cardId, instanceKey);
    }
  }

  minimizeCard(container, cardId, instanceKey) {
    const instanceData = this.datasetInstances.get(instanceKey);
    if (!instanceData) return;

    const cardBody = container.querySelector('.card-body');
    const toggleIcon = container.querySelector('.toggle-icon');

    // Remove from maximized history for this dataset instance
    instanceData.maximizedHistory = instanceData.maximizedHistory.filter(id => id !== cardId);

    container.classList.add('minimized');

    // Animate to vertical strip
    container.style.transition = 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
    container.style.width = '60px';
    container.style.minWidth = '60px';
    container.style.zIndex = '10';

    // Hide card body with fade
    if (cardBody) {
      cardBody.style.transition = 'opacity 0.2s ease';
      cardBody.style.opacity = '0';
      setTimeout(() => {
        cardBody.style.display = 'none';
      }, 200);
    }

    // Rotate icon
    if (toggleIcon) {
      toggleIcon.style.transform = 'rotate(180deg)';
    }

    // Add minimized class for CSS styling
    const headerText = container.querySelector('.card-header small');
    if (headerText) {
      setTimeout(() => {
        headerText.classList.add('minimized-text');
      }, 200);
    }
  }

  maximizeCard(container, cardId, instanceKey) {
    const instanceData = this.datasetInstances.get(instanceKey);
    if (!instanceData) return;

    // Check if we need to minimize the least recently maximized card in THIS dataset
    if (instanceData.maximizedHistory.length >= this.maxMaximizedCards) {
      const oldestCardId = instanceData.maximizedHistory[0];
      // Only look for cards within this dataset's container
      const oldestContainer = instanceData.container.querySelector(`[data-card-id="${oldestCardId}"]`);
      if (oldestContainer && !oldestContainer.classList.contains('minimized')) {
        this.minimizeCard(oldestContainer, oldestCardId, instanceKey);
      }
    }

    // Add to maximized history for this dataset instance
    instanceData.maximizedHistory = instanceData.maximizedHistory.filter(id => id !== cardId); // Remove if already exists
    instanceData.maximizedHistory.push(cardId); // Add to end

    const cardBody = container.querySelector('.card-body');
    const toggleIcon = container.querySelector('.toggle-icon');

    container.classList.remove('minimized');

    // Restore card size
    container.style.transition = 'all 0.4s cubic-bezier(0.4, 0, 0.2, 1)';
    container.style.width = '';
    container.style.minWidth = '';
    container.style.zIndex = '';

    // Restore header text
    const headerText = container.querySelector('.card-header small');
    if (headerText) {
      headerText.classList.remove('minimized-text');
    }

    // Show card body with fade in
    if (cardBody) {
      setTimeout(() => {
        cardBody.style.display = '';
        cardBody.style.transition = 'opacity 0.3s ease';
        cardBody.style.opacity = '1';
      }, 200);
    }

    // Rotate icon back
    if (toggleIcon) {
      toggleIcon.style.transform = 'rotate(0deg)';
    }
  }
}

// Initialize card toggler
window.scxrdCardToggler = new ScxrdCardToggler();
console.log('ScxrdCardToggler initialized');