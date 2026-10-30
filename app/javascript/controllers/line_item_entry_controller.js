import { Controller } from "@hotwired/stimulus"

// UX-only decimal preview: server independently computes the monetary total.
// No OCR, image parsing, or invented value takes place here.
export default class extends Controller {
  static targets = ["quantity", "unitPrice", "amount", "hint"]

  connect() {
    this.calculate()
  }

  calculate() {
    const qString = this.quantityTarget.value.trim()
    const pString = this.unitPriceTarget.value.trim()
    const active = /^\d+(?:\.\d{1,3})?$/.test(qString) &&
      /^\d+(?:\.\d{1,2})?$/.test(pString) &&
      Number(qString) > 0 && Number(pString) >= 0
    this.amountTarget.readOnly = active
    this.amountTarget.classList.toggle("is-calculated", active)
    this.hintTarget.classList.toggle("is-calculated", active)
    if (!active) return

    // BigInt decimal arithmetic avoids binary floating-point rounding errors
    // for ordinary VND values, retaining 3-digit quantity and 2-digit price.
    const decimalParts = (s, scale) => {
      const [whole, fraction = ""] = s.split(".")
      return BigInt(whole) * 10n ** BigInt(scale) +
        BigInt((fraction + "0".repeat(scale)).slice(0, scale))
    }
    try {
      const q = decimalParts(qString, 3)
      const p = decimalParts(pString, 2)
      const cents = (q * p + 500n) / 1000n
      this.amountTarget.value = (cents / 100n).toString() +
        "." + (cents % 100n).toString().padStart(2, "0")
    } catch (_) {
      this.amountTarget.readOnly = false
      this.amountTarget.classList.remove("is-calculated")
    }
  }
}
