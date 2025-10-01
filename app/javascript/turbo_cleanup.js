// Turbo navigation cleanup for CifVis and other visualization libraries
// This handles cleanup when navigating away from pages to prevent animation loops

class TurboCleanupManager {
  constructor() {
    this.cifVisInstances = new Set();
    this.animationFrames = new Set();
    this.intervals = new Set();
    this.timeouts = new Set();
    
    this.setupEventListeners();
  }

  setupEventListeners() {
    // Clean up when caching pages (before navigating away)
    document.addEventListener('turbo:before-cache', () => {
      console.log('Turbo: Cleaning up before caching page');
      this.cleanup();
    });

    // Clean up when visiting new pages
    document.addEventListener('turbo:before-visit', () => {
      console.log('Turbo: Cleaning up before visiting new page');
      this.cleanup();
    });

    // Also clean up on standard page unload as fallback
    window.addEventListener('beforeunload', () => {
      this.cleanup();
    });

    // Clean up when modals are hidden (specifically for well modal)
    document.addEventListener('hidden.bs.modal', (event) => {
      if (event.target.id === 'wellImagesModal') {
        console.log('Well modal hidden - running cleanup');
        this.cleanup();
      }
    });
  }

  // Register CifVis instances for cleanup
  registerCifVis(instance) {
    this.cifVisInstances.add(instance);
  }

  // Register animation frames for cleanup
  registerAnimationFrame(id) {
    this.animationFrames.add(id);
  }

  // Register intervals for cleanup
  registerInterval(id) {
    this.intervals.add(id);
  }

  // Register timeouts for cleanup
  registerTimeout(id) {
    this.timeouts.add(id);
  }

  cleanup() {
    // Clean up CifVis instances
    this.cifVisInstances.forEach(instance => {
      try {
        if (instance && typeof instance.destroy === 'function') {
          instance.destroy();
        } else if (instance && typeof instance.dispose === 'function') {
          instance.dispose();
        } else if (instance && instance.viewer && typeof instance.viewer.dispose === 'function') {
          instance.viewer.dispose();
        }
      } catch (error) {
        console.warn('Error cleaning up CifVis instance:', error);
      }
    });
    this.cifVisInstances.clear();

    // Clean up animation frames
    this.animationFrames.forEach(id => {
      try {
        cancelAnimationFrame(id);
      } catch (error) {
        console.warn('Error canceling animation frame:', error);
      }
    });
    this.animationFrames.clear();

    // Clean up intervals
    this.intervals.forEach(id => {
      try {
        clearInterval(id);
      } catch (error) {
        console.warn('Error clearing interval:', error);
      }
    });
    this.intervals.clear();

    // Clean up timeouts
    this.timeouts.forEach(id => {
      try {
        clearTimeout(id);
      } catch (error) {
        console.warn('Error clearing timeout:', error);
      }
    });
    this.timeouts.clear();

    // Clean up CifVis widgets specifically
    this.cleanupCifVisWidgets();

    // Clean up SCXRD diffraction viewers
    this.cleanupScxrdViewers();
  }

  cleanupCifVisWidgets() {
    console.log('Cleaning up CifVis widgets...');
    
    // Find all cifview-widget elements and try to clean them up
    const cifWidgets = document.querySelectorAll('cifview-widget');
    console.log(`Found ${cifWidgets.length} cifview-widget elements`);
    
    cifWidgets.forEach((widget, index) => {
      try {
        console.log(`Cleaning up cifview-widget ${index + 1}`);
        
        // Try to access the CifVis instance from the widget
        if (widget._cifvis) {
          if (typeof widget._cifvis.destroy === 'function') {
            widget._cifvis.destroy();
            console.log(`Destroyed CifVis instance ${index + 1}`);
          } else if (typeof widget._cifvis.dispose === 'function') {
            widget._cifvis.dispose();
            console.log(`Disposed CifVis instance ${index + 1}`);
          }
        }

        // Try to stop any animation loops by clearing the widget's properties
        if (widget._animation) {
          widget._animation = null;
        }
        
        // Stop any Three.js renderer if it exists
        if (widget._renderer) {
          widget._renderer.dispose();
          widget._renderer = null;
        }

        // Remove the widget from DOM to stop any remaining animations
        if (widget.parentNode) {
          widget.parentNode.removeChild(widget);
          console.log(`Removed cifview-widget ${index + 1} from DOM`);
        }
      } catch (error) {
        console.warn(`Error cleaning up cifview-widget ${index + 1}:`, error);
      }
    });

    // Also try to clean up any global CifVis instances
    if (window.CifVis) {
      try {
        // Try to access internal CifVis instances if available
        if (window.CifVis.instances) {
          window.CifVis.instances.forEach((instance, index) => {
            try {
              if (typeof instance.destroy === 'function') {
                instance.destroy();
                console.log(`Destroyed global CifVis instance ${index + 1}`);
              }
            } catch (error) {
              console.warn(`Error destroying global CifVis instance ${index + 1}:`, error);
            }
          });
          window.CifVis.instances = [];
        }
      } catch (error) {
        console.warn('Error cleaning up global CifVis instances:', error);
      }
    }
  }

  cleanupScxrdViewers() {
    // Clean up any SCXRD diffraction viewers
    Object.keys(window).forEach(key => {
      if (key.startsWith('scxrdViewer_')) {
        try {
          const viewer = window[key];
          if (viewer && typeof viewer.destroy === 'function') {
            viewer.destroy();
          }
          delete window[key];
        } catch (error) {
          console.warn(`Error cleaning up SCXRD viewer ${key}:`, error);
        }
      }
    });
  }
}

// Create global instance
window.turboCleanupManager = new TurboCleanupManager();

// Store original functions and override them to track IDs only
const originalRequestAnimationFrame = window.requestAnimationFrame;
const originalSetInterval = window.setInterval;
const originalSetTimeout = window.setTimeout;

// Only track animation frames without interfering with their execution
window.requestAnimationFrame = function(callback) {
  const id = originalRequestAnimationFrame.call(this, callback);
  if (window.turboCleanupManager) {
    window.turboCleanupManager.registerAnimationFrame(id);
  }
  return id;
};

// Override setInterval to track intervals
window.setInterval = function(callback, delay) {
  const id = originalSetInterval.call(this, callback, delay);
  if (window.turboCleanupManager) {
    window.turboCleanupManager.registerInterval(id);
  }
  return id;
};

// Override setTimeout to track timeouts
window.setTimeout = function(callback, delay) {
  const id = originalSetTimeout.call(this, callback, delay);
  if (window.turboCleanupManager) {
    window.turboCleanupManager.registerTimeout(id);
  }
  return id;
};

console.log('Turbo cleanup manager initialized');