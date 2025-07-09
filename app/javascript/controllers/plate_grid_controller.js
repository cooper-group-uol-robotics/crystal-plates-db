import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { rows: Number, columns: Number }

  connect() {
    const grid = document.createElement("table")
    for (let r = 0; r < this.rowsValue; r++) {
      const tr = document.createElement("tr")
      for (let c = 0; c < this.columnsValue; c++) {
        const td = document.createElement("td")
        td.textContent = `${String.fromCharCode(65 + r)}${c + 1}`
        td.classList.add("well")
        tr.appendChild(td)
      }
      grid.appendChild(tr)
    }
    this.element.appendChild(grid)
  }
}
