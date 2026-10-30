import { Controller } from "@hotwired/stimulus"

// Read-only inspection of a locked source record; never navigates away from
// an unsaved correction draft. The dialog is explicitly dismissed only.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event.preventDefault()
    if (!this.hasDialogTarget) return
    this.returnFocusTo = event.currentTarget
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }

  preventImplicitClose(event) {
    event.preventDefault()
  }

  restoreFocus() {
    if (this.returnFocusTo?.isConnected) this.returnFocusTo.focus()
    this.returnFocusTo = null
  }
}
