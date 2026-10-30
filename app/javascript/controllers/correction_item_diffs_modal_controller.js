import { Controller } from "@hotwired/stimulus"

// Inspect changed line items in-place without navigating away from a draft.
// Matches the explicit-dismiss behavior of the original-transaction modal.
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
