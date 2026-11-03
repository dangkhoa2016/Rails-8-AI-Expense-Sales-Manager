# Responsive line-item workbench

The transaction item page at `/finance/transactions/:id/line_items` prioritizes the item table immediately below the page heading, rather than placing the transaction date, reconciliation cards, alerts, and actions above it.

## Layout

- **Wide screens (1280px and above):** three columns. Left sidebar: the existing compact filter (name, HH:MM, amount, multiple item Tags). Center: the six-column sortable table, matched result summary and pagination. Right sidebar: shared transaction date, complete accounting reconciliation and the existing actions, correction notice and CSV import controls.
- **Medium screens (960–1279px):** two columns. Filter and context panels are grouped into one independently sized left-side stack, avoiding an artificial gap caused by a grid row being stretched to the table height; the table occupies the right rail with independent horizontal scrolling as needed.
- **Narrow screens (959px and below):** the collapsed filter remains compact at the top, immediately followed by responsive line-item cards, then the transaction context/actions. The responsive card conversion remains scoped to line items; it does not affect reports, Tag catalog or other app tables.

The global navigation, workspace context, original transaction date and full reconciliation amounts remain intact. The item list's `#line_item_list` element is replaced by existing Turbo Streams, while the filter rail and summary sidebar are independently retained or updated. The `#line_item_results` anchor still scrolls to matching items after a normal GET filter submission. Desktop heading-sort links, pagination, Turbo create/edit modals and multi-Tag query parameters are retained.

## Verification

Validate at 375, 414, 768, 959, 960, 1024, 1199, 1280, 1366 and 1472px. Check for no document-wide horizontal overflow, visible first item in the first viewport, correct sidebar ordering, internal table scrolling on medium widths, preserved filter and Tag selection, anchored GET submissions, and draft/confirmed behavior. Run the full Rails suite and targeted static/browser UI checks.

This is a presentation-only change: no model inference, data migration, mutation of confirmed transactions or production certification.

## Sidebar spacing and accessible labels (2026-10-31)

The sidebar stack shares no table-sized grid row with the main table, so the shared date, KPIs, notices and action controls follow the filter without a large blank region at 960–1279px. The column headings use concise **Time** and **Location** labels. The full optional descriptions remain unchanged in edit/new-item forms.

The filter disclosure now starts **expanded** at all breakpoints. At 959px and below, the expanded form has a scrollable height cap and a sticky Apply control, keeping a first item visible in the first viewport. Users can still collapse it via the native summary and the selected Tag logic remains unchanged.

## Validation after Kaggle restart — 2026-11-03

The restored Kaggle environment passed **136 Rails tests / 1,888 assertions** (zero failures, errors or skips), plus static responsive and JavaScript checks. An authenticated Chromium check verified 13 widths (375, 414, 768, 900, 959, 960, 1024, 1122, 1199, 1279, 1280, 1366 and 1472 px). Every size has the filter expanded by default, short Time/Location headings, no document-wide horizontal overflow, and the first row visible in the initial 916 px viewport. The 960–1279 px sidebar gap between filter and context is approximately 10 px. Multi-Tag filtering and direct result anchoring were checked at 375, 1122 and 1366 px.

Browser QA used a separate database restored from an existing synthetic snapshot (14 transactions, 282 line items), not the original in-memory/pre-restart development database (previously reported as 285 items). This snapshot is for UI testing only; no claim of exact data recovery or production certification is made.
