const assert = require("node:assert/strict")
const fs = require("node:fs")
const vm = require("node:vm")

const source = fs.readFileSync("app/javascript/controllers/item_modal_controller.js","utf8")
  .replace(/^import .*\n/,"")
  .replace("export default class extends Controller {", "class ItemModalController extends Controller {")
const context = { Controller: class {} }
vm.createContext(context)
vm.runInContext(source + "\nthis.ItemModalController = ItemModalController",context)
const c = new context.ItemModalController()
let closeCount=0,showCount=0,prevented=false,cleared=false
c.element={
  open:false,
  showModal(){this.open=true;showCount++},
  close(){this.open=false;closeCount++},
  closest(selector){assert.equal(selector,"turbo-frame");return {replaceChildren(){cleared=true}}}
}
c.connect()
assert.equal(showCount,1)
c.preventImplicitClose({preventDefault(){prevented=true}})
assert.equal(prevented,true)
assert.equal(closeCount,0)
assert.equal(c.element.open,true)
assert.equal(typeof c.backdrop,"undefined")
c.close()
assert.equal(closeCount,1)
c.onClose()
assert.equal(cleared,true)
for (const file of ["_modal.html.erb","_new_modal.html.erb"]) {
  const s=fs.readFileSync("app/views/finance/line_items/"+file,"utf8")
  assert.match(s,/cancel->item-modal#preventImplicitClose/)
  assert.doesNotMatch(s,/click->item-modal#backdrop/)
  assert.match(s,/<svg viewBox="0 0 24 24"/)
  assert.match(s,/class="item-modal-close"/)
  assert.match(s,/class="btn item-modal-cancel"/)
  assert.match(s,/data-action="item-modal#close"/)
}
const css=fs.readFileSync("app/assets/stylesheets/application.css","utf8")
assert.match(css,/\.item-edit-dialog \.item-modal-close\{\s*display:grid;place-items:center/)
assert.match(css,/\.item-edit-dialog \.form-footer \.item-modal-cancel/)
assert.match(css,/\.category-editor \.tag-status-toggle input\[type=checkbox\]/)
assert.match(css,/\.category-editor \.form-field input:not\(\[type=checkbox\]\)/)
assert.match(fs.readFileSync("app/views/finance/categories/index.html.erb","utf8"), /class="tag-status-toggle"/)
console.log("ITEM_MODAL_EXPLICIT_DISMISS_AND_STYLE_PASS")
