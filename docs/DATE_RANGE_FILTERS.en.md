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
