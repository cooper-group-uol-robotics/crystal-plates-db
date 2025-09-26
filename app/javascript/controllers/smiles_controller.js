import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { smiles: String, width: Number, height: Number }

  connect() {
    this.renderMolecule()
  }

  smilesValueChanged() {
    this.renderMolecule()
  }

  async renderMolecule() {
    if (!this.smilesValue || this.smilesValue.trim() === "") {
      this.canvasTarget.style.display = "none"
      return
    }

    try {
      // Wait for SmilesDrawer to be available
      await this.waitForSmilesDrawer()
      
      const width = this.widthValue || 200
      const height = this.heightValue || 200
      
      // Create a canvas element
      const canvas = document.createElement('canvas')
      canvas.width = width
      canvas.height = height
      
      // Create SmilesDrawer instance
      const smilesDrawer = new window.SmilesDrawer.Drawer({
        width: width,
        height: height,
        bondThickness: 2,
        bondSpacing: 0.18 * 15,
        atomVisualization: 'default',
        isomeric: true,
        debug: false,
        themes: {
          light: {
            C: '#222',
            O: '#e74c3c',
            N: '#3498db',
            F: '#27ae60',
            CL: '#16a085',
            BR: '#d35400',
            I: '#8e44ad',
            S: '#f39c12'
          }
        }
      })

      // Parse and draw the molecule
      window.SmilesDrawer.parse(this.smilesValue, (tree) => {
        if (!tree || tree.length === 0) {
          this.showError("Invalid SMILES structure")
          return
        }
        
        smilesDrawer.draw(tree, canvas, 'light')
        
        // Replace canvas content
        this.canvasTarget.innerHTML = ""
        this.canvasTarget.appendChild(canvas)
        this.canvasTarget.style.display = "block"
        
      }, (err) => {
        console.error("Error parsing SMILES:", err)
        this.showError("Error parsing SMILES")
      })
      
    } catch (error) {
      console.error("Error rendering molecule:", error)
      this.showError("Error rendering structure")
    }
  }

  waitForSmilesDrawer() {
    return new Promise((resolve) => {
      if (window.SmilesDrawer) {
        resolve()
      } else {
        const checkSmilesDrawer = () => {
          if (window.SmilesDrawer) {
            resolve()
          } else {
            setTimeout(checkSmilesDrawer, 100)
          }
        }
        checkSmilesDrawer()
      }
    })
  }

  showError(message) {
    this.canvasTarget.innerHTML = `<div class="text-muted small p-2 border rounded">${message}</div>`
    this.canvasTarget.style.display = "block"
  }
}
