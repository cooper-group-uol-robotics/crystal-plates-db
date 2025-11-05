import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus = application

document.addEventListener("turbo:render", () => {
    if (window.MiniProfiler && window.MiniProfiler.pageLoaded) {
        window.MiniProfiler.pageLoaded();
    }
});

export { application }
