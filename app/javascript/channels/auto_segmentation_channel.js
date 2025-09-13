// AutoSegmentationChannel - handled directly in views where needed
// This file exists to ensure proper asset compilation
import consumer from "channels/consumer"

// Export the consumer for use in other parts of the application
export { consumer }

// Note: Actual subscriptions are created dynamically in the image viewer
// to allow for image-specific channels
