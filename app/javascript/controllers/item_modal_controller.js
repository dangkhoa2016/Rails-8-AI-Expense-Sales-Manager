import { Controller } from "@hotwired/stimulus"

// An item dialog may contain unsaved financial details. Only explicit
// Close / Cancel controls dismiss it; backdrop clicks and Escape do not.
export default class extends Controller {
  connect() {
    if (!this.element.open) this.element.showModal()
  }

  close() {
    this.element.close()
  }

  preventImplicitClose(event) {
    // Native <dialog> emits 'cancel' on Escape. Keep unsaved edits visible.
    event.preventDefault()
  }

  onClose() {
    const frame = this.element.closest("turbo-frame")
    if (frame) frame.replaceChildren()
  }
}
