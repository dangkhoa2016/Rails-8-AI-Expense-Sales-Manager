import { Controller } from "@hotwired/stimulus"

// One intake experience. Switching the radio changes both submit paths, without
// navigating away or discarding an already-selected proof image / manual inputs.
export default class extends Controller {
  static targets = ["radio", "kind", "entryMode", "dateOptions"]

  connect() { this.select() }

  select() {
    const value = this.radioTargets.find((radio) => radio.checked)?.value || "expense"
    if (!["income", "expense"].includes(value)) return
    this.kindTargets.forEach((element) => { element.value = value })
    this.entryModeTargets.forEach((element) => {
      element.value = value === "income" ? "quick_income" : ""
    })
    // Income requires the verified transaction date, so do not hide the
    // date field inside a closed disclosure when Money in is selected.
    if (value === "income") {
      this.dateOptionsTargets.forEach((element) => { element.open = true })
    }
  }
}
