import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static targets = [
        "scoresContainer", "emptyMessage", "addForm", "addButton",
        "attributeSelect", "newAttributeFields", "attributeNameInput", "descriptionInput",
        "submitButton", "loadingMessage", "errorMessage", "successMessage"
    ]
    static values = {
        wellId: Number,
        plateBarcode: String
    }

    connect() {
        console.log("Custom attributes controller connected")
    }

    showAddForm() {
        this.hideMessages()
        this.addFormTarget.classList.remove('d-none')
        this.addButtonTarget.classList.add('d-none')
        this.attributeSelectTarget.focus()
    }

    cancelAdd() {
        this.addFormTarget.classList.add('d-none')
        this.addButtonTarget.classList.remove('d-none')
        this.clearForm()
    }

    attributeSelectChanged() {
        const selectedValue = this.attributeSelectTarget.value

        if (selectedValue === 'create_new') {
            this.newAttributeFieldsTarget.classList.remove('d-none')
            this.attributeNameInputTarget.focus()
        } else {
            this.newAttributeFieldsTarget.classList.add('d-none')
        }
    }

    async addAttribute() {
        const selectedValue = this.attributeSelectTarget.value

        if (!selectedValue) {
            this.showError('Please select an attribute or choose to create a new one')
            return
        }

        this.showLoading()

        try {
            let customAttributeId

            if (selectedValue === 'create_new') {
                // Create new attribute
                const attributeName = this.attributeNameInputTarget.value.trim()
                const description = this.descriptionInputTarget.value.trim()

                if (!attributeName) {
                    this.showError('Please enter an attribute name')
                    this.hideLoading()
                    return
                }

                customAttributeId = await this.createNewAttribute(attributeName, description)
            } else {
                // Use existing attribute
                customAttributeId = selectedValue
            }

            if (customAttributeId) {
                // Add attribute to all wells in the plate (with null/0 values initially)
                await this.addAttributeToAllWells(customAttributeId)
                this.showSuccess('Attribute added successfully! You can now set scores for each well.')
                this.reloadContent()
                this.cancelAdd()
            }
        } catch (error) {
            this.showError('Network error: ' + error.message)
        } finally {
            this.hideLoading()
        }
    }

    async updateScore(event) {
        const scoreId = event.target.dataset.scoreId
        const newValue = event.target.value

        if (!newValue) return

        try {
            const response = await fetch(`/api/v1/plates/${this.plateBarcodeValue}/wells/${this.wellIdValue}/well_scores/${scoreId}`, {
                method: 'PATCH',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
                },
                body: JSON.stringify({
                    value: parseFloat(newValue)
                })
            })

            if (!response.ok) {
                const data = await response.json()
                this.showError(data.error || 'Failed to update score')
                // Revert the input value
                event.target.value = event.target.defaultValue
            } else {
                this.showSuccess('Score updated successfully!')
            }
        } catch (error) {
            this.showError('Network error: ' + error.message)
            // Revert the input value
            event.target.value = event.target.defaultValue
        }
    }

    async deleteScore(event) {
        const scoreId = event.target.dataset.scoreId

        if (!confirm('Are you sure you want to delete this attribute score?')) {
            return
        }

        try {
            const response = await fetch(`/api/v1/plates/${this.plateBarcodeValue}/wells/${this.wellIdValue}/well_scores/${scoreId}`, {
                method: 'DELETE',
                headers: {
                    'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
                }
            })

            if (response.ok) {
                this.showSuccess('Score deleted successfully!')
                this.reloadContent()
            } else {
                const data = await response.json()
                this.showError(data.error || 'Failed to delete score')
            }
        } catch (error) {
            this.showError('Network error: ' + error.message)
        }
    }

    async createNewAttribute(name, description) {
        const response = await fetch(`/api/v1/custom_attributes`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
            },
            body: JSON.stringify({
                custom_attribute: {
                    name: name,
                    description: description,
                    data_type: 'numeric'
                }
            })
        })

        const data = await response.json()

        if (response.ok) {
            return data.data ? data.data.id : data.id
        } else {
            throw new Error(data.error || 'Failed to create custom attribute')
        }
    }

    async addAttributeToAllWells(customAttributeId) {
        const response = await fetch(`/api/v1/plates/${this.plateBarcodeValue}/custom_attributes/${customAttributeId}/add_to_all_wells`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
            }
        })

        const data = await response.json()

        if (!response.ok) {
            throw new Error(data.error || 'Failed to add attribute to wells')
        }

        return data
    }

    async reloadContent() {
        try {
            const response = await fetch(`/wells/${this.wellIdValue}/custom_attributes`, {
                headers: {
                    'Accept': 'text/html'
                }
            })
            if (response.ok) {
                const html = await response.text()
                this.element.outerHTML = html
            }
        } catch (error) {
            console.error('Failed to reload custom attributes content:', error)
        }
    }

    clearForm() {
        this.attributeSelectTarget.value = ''
        this.newAttributeFieldsTarget.classList.add('d-none')
        this.attributeNameInputTarget.value = ''
        this.descriptionInputTarget.value = ''
    }

    showLoading() {
        this.hideMessages()
        this.loadingMessageTarget.classList.remove('d-none')
        this.submitButtonTarget.disabled = true
    }

    hideLoading() {
        this.loadingMessageTarget.classList.add('d-none')
        this.submitButtonTarget.disabled = false
    }

    showError(message) {
        this.hideMessages()
        this.errorMessageTarget.textContent = message
        this.errorMessageTarget.classList.remove('d-none')
    }

    showSuccess(message) {
        this.hideMessages()
        this.successMessageTarget.textContent = message
        this.successMessageTarget.classList.remove('d-none')

        // Auto-hide success message after 3 seconds
        setTimeout(() => {
            this.successMessageTarget.classList.add('d-none')
        }, 3000)
    }

    hideMessages() {
        this.errorMessageTarget.classList.add('d-none')
        this.successMessageTarget.classList.add('d-none')
        this.loadingMessageTarget.classList.add('d-none')
    }
}