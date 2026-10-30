import { Controller } from "@hotwired/stimulus"

// Adds/removes a handful of inline draft items. Large receipts use the
// paginated item manager and atomic CSV import instead of 100+ DOM form fields.
export default class extends Controller {
  static targets = ["list", "template"]
  static values = { nextPosition: Number }

  connect() {
    this.sequence = 0
  }

  add(event) {
    event.preventDefault()
    if (!this.hasTemplateTarget || !this.hasListTarget) return
    const index = `new_${Date.now()}_${++this.sequence}`
    const markup = this.templateTarget.innerHTML
      .replaceAll("NEW_ROW", index)
      .replaceAll("NEW_POSITION", String(this.nextPositionValue++))
    this.listTarget.insertAdjacentHTML("beforeend", markup)
  }

  remove(event) {
    event.preventDefault()
    const row = event.currentTarget.closest("[data-line-row]")
    if (!row) return
    const destroy = row.querySelector("[data-line-destroy]")
    const id = row.querySelector('input[name$="[id]"]')
    if (destroy && id && id.value) {
      destroy.checked = true
      row.hidden = true
    } else {
      row.remove()
    }
  }
}
