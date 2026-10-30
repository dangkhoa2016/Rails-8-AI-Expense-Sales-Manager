const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")

// Execute the Stimulus controller logic with fake input elements.
// Tests live arithmetic behavior without a browser or an API connection.
const source = fs.readFileSync("app/javascript/controllers/line_item_entry_controller.js", "utf8")
  .replace(/^import .*\n/, "")
  .replace("export default class extends Controller {", "class LineItemEntryController extends Controller {")
const context = { Controller: class {}, BigInt, Number }
vm.createContext(context)
vm.runInContext(source + "\nthis.LineItemEntryController = LineItemEntryController", context)

function element(value) {
  const classes = new Set()
  return {
    value, readOnly: false, classList: {
      toggle(name, enabled) { if (enabled) classes.add(name); else classes.delete(name) },
      remove(name) { classes.delete(name) },
      contains(name) { return classes.has(name) }
    }
  }
}

function check(q, p, expected) {
  const c = new context.LineItemEntryController()
  c.quantityTarget = element(q)
  c.unitPriceTarget = element(p)
  c.amountTarget = element("999")
  c.hintTarget = element("")
  c.connect()
  assert.equal(c.amountTarget.value, expected)
  assert.equal(c.amountTarget.readOnly, true)
  assert.equal(c.amountTarget.classList.contains("is-calculated"), true)
  return c
}

const c = check("2", "15000", "30000.00")
c.quantityTarget.value = "3.5"
c.calculate()
assert.equal(c.amountTarget.value, "52500.00")
check("1.125", "1234.56", "1388.88")
check("0.001", "0.01", "0.00")
const noPrice = new context.LineItemEntryController()
noPrice.quantityTarget = element("1")
noPrice.unitPriceTarget = element("")
noPrice.amountTarget = element("9500")
noPrice.hintTarget = element("")
noPrice.calculate()
assert.equal(noPrice.amountTarget.value, "9500")
assert.equal(noPrice.amountTarget.readOnly, false)
assert.match(source, /keyup->line-item-entry#calculate|calculate\(\)/)
console.log("LINE_ITEM_ENTRY_JS_PASS: 6 arithmetic and manual-entry checks")
