import { Controller } from "@hotwired/stimulus"

// UTC date-only arithmetic avoids local timezone rollover.
// The server is authoritative; all preset ranges are recomputed on GET.
export default class extends Controller {
  static targets = ["preset", "from", "to"]
  static values = { today: String }

  applyPreset() {
    const preset = this.presetTarget.value
    if (preset === "custom") return
    if (preset === "all") {
      this.fromTarget.value = ""
      this.toTarget.value = ""
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
  }

  markCustom() {
    this.presetTarget.value = "custom"
  }
}
