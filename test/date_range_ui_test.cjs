const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync("app/javascript/controllers/date_range_controller.js", "utf8")
  .replace(/^import .+\n/m, "")
  .replace("export default class extends Controller", "class DateRange extends Controller");
const listeners = new Map();
const context = {
  Controller: class {}, Date,
  window: {
    addEventListener: (name, fn) => listeners.set(name, fn),
    removeEventListener: (name, fn) => {
      if (listeners.get(name) === fn) listeners.delete(name);
    }
  }
};
vm.createContext(context);
vm.runInContext(source + "\nthis.DateRange = DateRange;", context);

function verify(preset, today, from, to) {
  const c = new context.DateRange();
  c.todayValue = today;
  c.presetTarget = { value: preset };
  c.fromTarget = { value: "" };
  c.toTarget = { value: "" };
  c.applyPreset();
  assert.equal(c.fromTarget.value, from, preset + " from");
  assert.equal(c.toTarget.value, to, preset + " to");
  c.markCustom();
  assert.equal(c.presetTarget.value, "custom");
}

verify("this_week", "2026-10-31", "2026-10-26", "2026-11-01");
verify("previous_week", "2027-01-01", "2026-12-21", "2026-12-27");
verify("first_two_weeks_this_month", "2026-10-31", "2026-10-01", "2026-10-14");
verify("last_two_weeks_this_month", "2026-10-31", "2026-10-18", "2026-10-31");
verify("last_two_weeks_this_month", "2028-02-12", "2028-02-16", "2028-02-29");
verify("this_month", "2026-10-31", "2026-10-01", "2026-10-31");
verify("previous_month", "2026-01-04", "2025-12-01", "2025-12-31");
verify("last_7_days", "2026-01-01", "2025-12-26", "2026-01-01");
verify("last_30_days", "2026-10-31", "2026-10-02", "2026-10-31");
verify("all", "2026-10-31", "", "");
const custom = new context.DateRange();
custom.presetTarget = { value: "custom" };
custom.fromTarget = { value: "2026-08-10" };
custom.toTarget = { value: "2026-08-20" };
custom.applyPreset();
assert.equal(custom.fromTarget.value, "2026-08-10");
assert.equal(custom.toTarget.value, "2026-08-20");
console.log("DATE_RANGE_PRESET_JS_PASS: 10 presets and custom");

// Applied server values must take precedence over stale browser-restored values.
const note = { hidden: true };
const report = { querySelector: () => note };
const applied = new context.DateRange();
applied.element = { closest: () => report, querySelector: () => null };
applied.todayValue = "2026-10-31";
applied.appliedPresetValue = "last_two_weeks_this_month";
applied.appliedFromValue = "2026-10-18";
applied.appliedToValue = "2026-10-31";
applied.presetTarget = { value: "this_week" };
applied.fromTarget = { value: "2026-10-26" };
applied.toTarget = { value: "2026-11-01" };
applied.connect();
assert.equal(applied.presetTarget.value, "last_two_weeks_this_month");
assert.equal(applied.fromTarget.value, "2026-10-18");
assert.equal(applied.toTarget.value, "2026-10-31");
assert.equal(note.hidden, true);
applied.presetTarget.value = "this_week";
applied.applyPreset();
assert.equal(applied.fromTarget.value, "2026-10-26");
assert.equal(applied.toTarget.value, "2026-11-01");
assert.equal(note.hidden, false, "Changed but unsubmitted dates are marked pending");
listeners.get("pageshow")({ persisted: true });
assert.equal(applied.presetTarget.value, "last_two_weeks_this_month");
assert.equal(applied.fromTarget.value, "2026-10-18");
assert.equal(note.hidden, true);
applied.disconnect();
assert.equal(listeners.has("pageshow"), false);
console.log("DATE_RANGE_STATE_RESTORATION_AND_PENDING_PASS");
