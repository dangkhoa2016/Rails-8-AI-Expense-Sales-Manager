# Date-range filtering: Transactions and Reports

The Transactions history page (`/finance/transactions`) and human-confirmed Reports (`/finance/reports`) now share one date-only range resolver. All date comparisons use the transaction's **transaction_date**, not the upload, edit, confirmation or item timestamp. The business calendar follows **Asia/Ho_Chi_Minh**; the week starts **Monday** and ends Sunday. Both endpoints support strict ISO `from=YYYY-MM-DD&to=YYYY-MM-DD` with inclusive boundaries.

## Available quick presets

| Preset | Definition |
|---|---|
| This week | Monday–Sunday of the current week |
| Previous week | Monday–Sunday of the preceding week |
| First 2 weeks of this month | Days 1–14 |
| Last 2 weeks of this month | Exactly the last 14 calendar days, inclusive (Oct 18–31, 2026) |
| This month | First through last day of current month |
| Previous month | First through last day of preceding month |
| Last 7 days | Today and preceding six days |
| Last 30 days | Today and preceding 29 days |
| Custom dates | Inclusive validated From and To dates |
| All dates | Transactions history only |

Choosing a preset fills the date fields in the browser; changing either date switches the selector to **Custom dates**. The Rails resolver independently calculates recognized presets (JavaScript is convenience, not authority). In custom mode, both dates are required, ISO-formatted, between 1900 and 2100 and ordered. Reports limit custom ranges to approximately ten years to bound month-chart rendering; invalid inputs are rejected with HTTP 400, never interpolated into SQL.

## Default state and compatibility

- Transactions history starts with **All dates** and keeps the existing search, kind, status, 20-entry pagination and workspace boundaries. Pagination links retain the selected date range. If a date range is selected, income, expense and net KPIs also follow that range; in the default All-dates view, the KPIs remain **This month** as labeled.
- Reports defaults to **This month**. It uses the **same inclusive period** for confirmed-only income, expense, net, count, primary-Tag allocation, item allocation, daily totals, recent transactions and CSV export. A report compares the selected range to the **immediately preceding period of equal length**. The monthly trend displays months overlapping the chosen range, with horizontally scrolling bars for extended periods. The open drafts count remains a separate workspace-wide operational metric.
- Report links of the prior form `/finance/reports?month=2026-10` and `/finance/reports/export?month=2026-10` continue to resolve correctly. Export filename includes both dates, and the CSV contains only effective confirmed transactions in the selected range.
- Switching from the filtered history page to Reports, or from Reports to History, preserves the date selection. Results follow the existing confirmed-correction rule and never count an original and its confirmed replacement twice.

No migration, accounting ledger changes or OCR inference are involved. Unit/integration tests cover month/year boundaries, leap days, invalid ranges, tenant isolation, pagination and CSV; the browser preset logic has an independent JavaScript regression test.

## Responsive filter and browser-restored form state (2026-10-31)

The Reports filter uses a dedicated responsive grid: on wide screens the preset, date fields and actions form one balanced row; on tablets the action buttons move below the fields; on small phones all controls stack vertically with full-width buttons. The audit note is always displayed on its own line beneath the applied date range. The ledger history retains its existing responsive form with the same server-state safeguard.

The selected preset and date values in the URL represent the **applied** query. Browsers may retain unsubmitted form edits after page navigation, so the Stimulus controller restores these three controls from server-rendered applied values upon connection and on browser back/forward cache restoration. It **never recalculates or overwrites dates on initial page load**. After an intentional preset/date change, the form shows a localized **not yet applied** notice until the user submits the filter. The financial summary and CSV remain based on the applied server range, not unsubmitted fields.

Authenticated Chromium checks cover both pages at viewport widths 375, 414, 768, 1024, 1366 and 1472px, including applied-value consistency, responsive overflow/overlap checks and the pending-selection state. These are presentation-only changes: no schema, financial record or reporting calculation modifications.

## Multi-Tag filtering (2026-10-31)

Both Transactions History and Reports now support selecting **one or more Tags** alongside the existing date range. Open **Filter by multiple Tags** and select any number of tenant Tags (up to 50). Archived Tags remain visible for investigating historic records. Select none to include all Tags, including untagged transactions.

The match rule is **ANY (logical OR)** across direct transaction Tags and line-item Tags. **Amount attribution** is more precise than the transaction match: if any selected Tag is attached directly to the transaction, its **entire original amount** is attributed once. Otherwise, **only line items carrying a selected Tag contribute to the filtered amount**, and each matching line item contributes only once even if it carries multiple selected Tags. Other lines from the same receipt do **not** contribute. The transaction continues to appear in History for investigation, with both **matched amount** and **original transaction amount** shown. No stored amount is changed.

Date, status, type, search and pagination combine with Tag selection on History. Its financial KPIs and visible amounts show **attributed money**, while the immutable original value remains separately visible. Reports use attributed money consistently for confirmed income/expense/net, the preceding equal-length period, selected-Tag allocation, daily/monthly charts and recent transactions. In the Tag-filtered view, the duplicate item-allocation chart is hidden because the selected-Tag allocation already reconciles to the filtered expense total. Reports' open-draft count remains workspace-wide. CSV retains the immutable original **Amount** column and adds **MatchedTagAmount**, which is the correct field to sum for the filtered KPI. Without a Tag filter the original report and CSV behavior is unchanged.

The **View history for this range** action is now a distinct, bordered, responsive button with an icon, and it preserves both selected Tags and date filters. Report CSV download does likewise. Tag IDs are verified against the current workspace; invalid/foreign IDs are rejected (HTTP 400), never resolved against another tenant. The feature needs no migration or alteration to any ledger or historical audit record.
