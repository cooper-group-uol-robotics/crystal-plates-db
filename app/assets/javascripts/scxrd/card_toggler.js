// Card Toggle Functionality
class ScxrdCardToggler {
  constructor() {
    this.maxMaximizedCards = 3;
    this.maximizedHistory = []; // Track order of maximization
    this.initializeToggleHandlers();
  }

  initializeToggleHandlers() {
    // Wait for DOM to be ready
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
    this.maximizedHistory = [];
    this.setupCardToggles();
  }

  setupCardToggles() {
    const cardContainers = document.querySelectorAll('[data-card-id]');
    cardContainers.forEach(container => {
      const header = container.querySelector('.card-header');
      const cardId = container.getAttribute('data-card-id');

      if (header && !header.classList.contains('toggle-initialized')) {
        header.style.cursor = 'pointer';
        header.style.userSelect = 'none';
        header.addEventListener('click', () => this.toggleCard(cardId));

        // Add visual indication that it's clickable
        header.innerHTML += ' <i class="fas fa-chevron-up toggle-icon ms-1" style="font-size: 0.8em; transition: transform 0.3s ease;"></i>';

        // Mark as initialized to avoid duplicate handlers
        header.classList.add('toggle-initialized');
      }
    });

    // Initialize default states
    this.initializeDefaultStates();
  }

  initializeDefaultStates() {
    // Initialize the first 3 cards as maximized
    const allCards = document.querySelectorAll('[data-card-id]');
    allCards.forEach((container, index) => {
      const cardId = container.getAttribute('data-card-id');
      if (index < 3 && !container.classList.contains('minimized')) {
        // Add to maximized history for the first 3 cards
        this.maximizedHistory.push(cardId);
      } else if (container.classList.contains('minimized')) {
        // Ensure minimized cards have the right styling
        this.applyMinimizedStyling(container);
      }
    });
  }

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

  toggleCard(cardId) {
    const container = document.querySelector(`[data-card-id="${cardId}"]`);
    if (!container) return;

    const isMinimized = container.classList.contains('minimized');

    if (isMinimized) {
      this.maximizeCard(container, cardId);
    } else {
      this.minimizeCard(container, cardId);
    }
  }

  minimizeCard(container, cardId) {
    const cardBody = container.querySelector('.card-body');
    const toggleIcon = container.querySelector('.toggle-icon');

    // Remove from maximized history
    this.maximizedHistory = this.maximizedHistory.filter(id => id !== cardId);

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

  maximizeCard(container, cardId) {
    // Check if we need to minimize the least recently maximized card
    if (this.maximizedHistory.length >= this.maxMaximizedCards) {
      const oldestCardId = this.maximizedHistory[0];
      const oldestContainer = document.querySelector(`[data-card-id="${oldestCardId}"]`);
      if (oldestContainer && !oldestContainer.classList.contains('minimized')) {
        this.minimizeCard(oldestContainer, oldestCardId);
      }
    }

    // Add to maximized history
    this.maximizedHistory = this.maximizedHistory.filter(id => id !== cardId); // Remove if already exists
    this.maximizedHistory.push(cardId); // Add to end

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