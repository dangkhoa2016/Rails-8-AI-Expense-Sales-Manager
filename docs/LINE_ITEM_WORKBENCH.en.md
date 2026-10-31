# Responsive line-item workbench

The transaction item page at `/finance/transactions/:id/line_items` prioritizes the item table immediately below the page heading, rather than placing the transaction date, reconciliation cards, alerts, and actions above it.

## Layout

- **Wide screens (1280px and above):** three columns. Left sidebar: the existing compact filter (name, HH:MM, amount, multiple item Tags). Center: the six-column sortable table, matched result summary and pagination. Right sidebar: shared transaction date, complete accounting reconciliation and the existing actions, correction notice and CSV import controls.
- **Medium screens (960–1279px):** two columns. Filter and context panels stack in the left rail; the table occupies the right rail with independent horizontal scrolling as needed.
- **Narrow screens (959px and below):** the collapsed filter remains compact at the top, immediately followed by responsive line-item cards, then the transaction context/actions. The responsive card conversion remains scoped to line items; it does not affect reports, Tag catalog or other app tables.

The global navigation, workspace context, original transaction date and full reconciliation amounts remain intact. The item list's `#line_item_list` element is replaced by existing Turbo Streams, while the filter rail and summary sidebar are independently retained or updated. The `#line_item_results` anchor still scrolls to matching items after a normal GET filter submission. Desktop heading-sort links, pagination, Turbo create/edit modals and multi-Tag query parameters are retained.

## Verification

Validate at 375, 414, 768, 959, 960, 1024, 1199, 1280, 1366 and 1472px. Check for no document-wide horizontal overflow, visible first item in the first viewport, correct sidebar ordering, internal table scrolling on medium widths, preserved filter and Tag selection, anchored GET submissions, and draft/confirmed behavior. Run the full Rails suite and targeted static/browser UI checks.

This is a presentation-only change: no model inference, data migration, mutation of confirmed transactions or production certification.
