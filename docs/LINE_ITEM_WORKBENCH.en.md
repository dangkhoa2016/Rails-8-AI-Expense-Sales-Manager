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

## Simplified reconciliation summary — 2026-11-03

The line-item sidebar now shows **three** compact values: number of items, sum of item amounts, and transaction amount. The always-visible difference card and its long explanatory notice were removed. The transaction detail hero also no longer repeats the difference.

Financial reconciliation remains in the controllers and domain services. New draft line-item create/edit/delete/import flows synchronize the draft total to the item sum; confirmations of line-total-managed drafts enforce equality. **Historical records, deliberate adjustments, and transactions without item rows do not necessarily have a zero difference.** When at least one line item exists and the transaction amount differs from the item sum, the interface shows a *conditional*, read-only “Amount outside itemized list” note instead of a redundant KPI. This may be a fee, tax, discount, or historical adjustment and must be reviewed against the original record. Transactions without item rows do not receive this warning. Confirmed records are never modified by displaying the note.

The same conditional note is used on the transaction detail page. Turbo Stream updates retain the original `line_items_summary` target so draft item changes update the three KPIs. Scope, sorting, multi-Tag filtering and historical audit evidence are unchanged.

## Unified total and visible line-item actions — 2026-11-03

The two amounts **Sum of item amounts** and **Transaction amount** are intentionally not repeated when they are equal. For balanced itemized transactions the sidebar shows only the item count and the stored transaction total. For transactions with at least one line item and a genuine difference (for example historical fees or discounts), both totals remain visible together with the existing read-only adjustment note. For transactions with no items the empty item sum is not shown. This is display-only; transaction amounts, reconciliation and immutable confirmed originals are unchanged.

A 2-column workbench at **960–1559px** leaves insufficient horizontal room for a complete six-column table at some narrower widths. At **1199px and below**, the list uses semantic, full-width responsive item cards, keeping all actions within each card without horizontal scrolling or cropped right edges. At **1200px and above**, a table is retained; three workbench columns begin at **1560px** to leave adequate width for the central table. The same row IDs, Turbo modal links, per-item Tags, filters, sorting URLs and 25-row pagination remain intact.

In a **draft**, every item card exposes both **Edit item** and **Delete item**. In a **confirmed** transaction, direct delete is not offered: immutable originals can be corrected only through an explicitly created correction draft. A short notice above the list explains this, and the Edit item action remains visible for initiating the correction workflow.

QA: full Rails suite and authenticated Chromium at 15 widths (375, 414, 768, 959, 960, 998, 1024, 1122, 1199, 1200, 1280, 1366, 1472, 1560 and 1600px). Verify balanced and exceptional totals and button visibility on both confirmed and draft transactions.

## Compact Edit/Delete controls — 2026-11-03

Only the item-row **Edit item** and **Delete item** buttons have reduced vertical padding. Both use 4px top/bottom on large screens (34px minimum height), 5px at widths up to 1199px (38px minimum), and 5px on phones up to 500px (40px minimum for touch). The buttons share aligned heights and compact rounded corners. The delete button now has a distinct light-red surface, red label and border, plus explicit hover and keyboard-focus states instead of the generic minimal/neutral button style.

The delete action is still a real POST form with Rails' DELETE override and the pre-existing Turbo confirmation dialog. The button only exists for draft line items; confirmed transactions do not expose direct deletion and must use a correction draft. CSS selectors are scoped to `#line_item_list`, so unrelated delete buttons and forms retain their own styles.

Regression: Rails suite and Chromium measurement of actual CSS padding, heights, delete-button color, focus/hover, clipping and draft-versus-confirmed behavior at 375, 414, 768, 960, 998, 1122, 1199, 1200, 1366 and 1560px.

## Desktop inline action buttons — 2026-11-03

On table layouts **1200px and above**, Edit and Delete now appear **side by side on one row**, with equal 66px button widths, 34px heights, and a 5px gap. The table presents the concise **Edit / Delete** labels (instead of the long Edit item details label), while the Edit link retains its full descriptive `aria-label` for assistive technologies and its Turbo modal target. At widths below 1200px, item cards retain the original full **Edit item details** label and existing responsive button behavior. The warning-red Delete style, confirmation dialog, and confirmed-transaction immutability are unchanged.

Chromium measured actual button positions at 998, 1200, 1280, 1366, 1515, 1560, 1600 and 1920px; from 1200px both buttons stay on the same line, with matching widths/heights, and no horizontal document overflow. Rails integration tests verify the localized full/compact labels and accessible name.
