import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = ["plateBarcode"]

    connect() {
        console.log('PlateBuilder controller connected successfully!')
        console.log('Element:', this.element)
        console.log('Targets available:', this.constructor.targets)

        if (this.hasPlateBarcodeTarget) {
            console.log('Plate barcode target found:', this.plateBarcodeTarget)
            this.plateBarcodeTarget.focus()
        } else {
            console.log('Plate barcode target NOT found')
        }
    }

    plateBarcodeKeypress(event) {
        console.log('Plate barcode keypress:', event.key, event.target.value)
        if (event.key === 'Enter') {
            console.log('Enter key pressed, value:', event.target.value.trim())
            alert('Plate barcode entered: ' + event.target.value.trim())
        }
    }
}