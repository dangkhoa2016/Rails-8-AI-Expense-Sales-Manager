import { Controller } from "@hotwired/stimulus"

// UTC date-only arithmetic avoids local timezone rollover.
// The server is authoritative; all preset ranges are recomputed on GET.
export default class extends Controller {
  static targets = ["preset", "from", "to"]
  static values = {
    today: String, appliedPreset: String, appliedFrom: String, appliedTo: String
  }

  connect() {
    // Browser form restoration / Turbo cache can rehydrate stale input values.
    // Always initialize the controls from the server-applied query, not the
    // user's last unsubmitted values. Never calculate a new preset here.
    this.restoreAppliedState()
    this.onPageShow = (event) => {
      if (event.persisted) this.restoreAppliedState()
    }
    window.addEventListener("pageshow", this.onPageShow)
  }

  disconnect() {
    window.removeEventListener("pageshow", this.onPageShow)
  }

  restoreAppliedState() {
    this.presetTarget.value = this.appliedPresetValue
    this.fromTarget.value = this.appliedFromValue
    this.toTarget.value = this.appliedToValue
    this.updatePendingState()
  }

  pendingNote() {
    return this.element?.closest(".report-filter")?.querySelector("[data-date-range-pending-note]") ||
      this.element?.querySelector("[data-date-range-pending-note]")
  }

  updatePendingState() {
    const changed = this.presetTarget.value !== this.appliedPresetValue ||
      this.fromTarget.value !== this.appliedFromValue ||
      this.toTarget.value !== this.appliedToValue
    const note = this.pendingNote()
    if (note) note.hidden = !changed
  }

  applyPreset() {
    const preset = this.presetTarget.value
    if (preset === "custom") {
      this.updatePendingState()
      return
    }
    if (preset === "all") {
      this.fromTarget.value = ""
      this.toTarget.value = ""
      this.updatePendingState()
      return
    }

    const [year, month, day] = this.todayValue.split("-").map(Number)
    const today = new Date(Date.UTC(year, month - 1, day))
    const shift = (d, offset) => new Date(d.getTime() + offset * 86400000)
    const first = new Date(Date.UTC(year, month - 1, 1))
    const last = new Date(Date.UTC(year, month, 0))
    const iso = (d) => d.toISOString().slice(0, 10)
    const monday = shift(today, -(today.getUTCDay() + 6) % 7)
    let from, to

    switch (preset) {
      case "this_week": from = monday; to = shift(monday, 6); break
      case "previous_week": from = shift(monday, -7); to = shift(monday, -1); break
      case "first_two_weeks_this_month": from = first; to = shift(first, 13); break
      case "last_two_weeks_this_month": from = shift(last, -13); to = last; break
      case "this_month": from = first; to = last; break
      case "previous_month":
        from = new Date(Date.UTC(year, month - 2, 1))
        to = new Date(Date.UTC(year, month - 1, 0))
        break
      case "last_7_days": from = shift(today, -6); to = today; break
      case "last_30_days": from = shift(today, -29); to = today; break
      default: return
    }
    this.fromTarget.value = iso(from)
    this.toTarget.value = iso(to)
    this.updatePendingState()
  }

  markCustom() {
    this.presetTarget.value = "custom"
    this.updatePendingState()
  }
}
