import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "instructions", 
    "loading", 
    "results", 
    "error", 
    "importButton", 
    "resultsSummary", 
    "errorMessage"
  ]

  connect() {
    console.log("Sciformation Import controller connected")
  }

  startImport() {
    console.log("startImport method called")
    this.showInstructions()
    this.getCookieAndImport()
  }

  async getCookieAndImport() {
    try {
      // Get the SCIFORMATION cookie from user
      const cookie = await this.getSciFormationCookie()
      
      if (!cookie) {
        this.showError("Import cancelled - no cookie provided.")
        return
      }

      // Start the import with the extracted cookie
      this.showLoading()
      await this.performImport(cookie)
    } catch (error) {
      console.error("Import error:", error)
      this.showError(`Import failed: ${error.message}`)
    }
  }

  async getSciFormationCookie() {
    // Due to browser security restrictions, we can't automatically extract cookies from other domains
    // So we'll provide clear instructions to the user
    
    const instructions = `
To get your Sciformation cookie:

1. Keep this dialog open
2. Open a new tab and go to https://jfb.liverpool.ac.uk
3. Log in if needed
4. Press F12 to open Developer Tools
5. Go to the "Application" or "Storage" tab
6. Look for "Cookies" in the left sidebar
7. Click on "https://jfb.liverpool.ac.uk"
8. Find the cookie named "SCIFORMATION" 
9. Copy its Value (the long string)
10. Paste it below

This is a one-time setup - the import will happen automatically once you paste the cookie.
    `.trim()
    
    alert(instructions)
    
    const cookie = prompt("Paste your SCIFORMATION cookie value here:")
    return cookie ? cookie.trim() : null
  }

  async performImport(cookie) {
    try {
      const response = await fetch("/chemicals/import_from_sciformation", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.getCSRFToken()
        },
        body: JSON.stringify({ sciformation_cookie: cookie })
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`)
      }

      const result = await response.json()
      
      if (result.success) {
        this.showResults(result)
      } else {
        this.showError(result.error || "Import failed for unknown reason")
      }
    } catch (error) {
      throw new Error(`Network error: ${error.message}`)
    }
  }

  showInstructions() {
    this.hideAll()
    this.instructionsTarget.classList.remove("d-none")
  }

  showLoading() {
    this.hideAll()
    this.loadingTarget.classList.remove("d-none")
    this.importButtonTarget.disabled = true
  }

  showResults(result) {
    this.hideAll()
    this.resultsTarget.classList.remove("d-none")
    this.importButtonTarget.disabled = false
    
    const summary = `
      <ul class="mb-0">
        <li>Total records processed: ${result.total_records || 0}</li>
        <li>New chemicals imported: ${result.imported || 0}</li>
        <li>Existing chemicals updated: ${result.updated || 0}</li>
        <li>Records skipped: ${result.skipped || 0}</li>
        <li>Total chemicals in database: ${result.total_chemicals || 0}</li>
      </ul>
    `
    this.resultsSummaryTarget.innerHTML = summary
    
    // Refresh the page to show new chemicals
    setTimeout(() => {
      window.location.reload()
    }, 3000)
  }

  showError(message) {
    this.hideAll()
    this.errorTarget.classList.remove("d-none")
    this.errorMessageTarget.textContent = message
    this.importButtonTarget.disabled = false
  }

  hideAll() {
    this.instructionsTarget.classList.add("d-none")
    this.loadingTarget.classList.add("d-none")
    this.resultsTarget.classList.add("d-none")
    this.errorTarget.classList.add("d-none")
  }

  getCSRFToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.getAttribute('content') : ''
  }
}
