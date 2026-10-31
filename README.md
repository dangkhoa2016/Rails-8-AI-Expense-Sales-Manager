# Rails 8 AI Expense & Sales Manager

Ruby on Rails 8 and PostgreSQL application for human-verified income/expense tracking, receipt image history and financial reporting.

Vietnamese: [README.vi.md](README.vi.md)

## Features

- Rails 8 authentication with private, per-account workspaces
- Manual income and expense drafts, with or without receipt images
- User-confirmed transaction dates and amounts (never inferred from upload timestamp or EXIF)
- Receipt versions stored privately in Active Storage with SHA256 and upload metadata
- Independent AI extraction runs and per-field proposals; no automatic financial posting
- Separate readable, partially_readable, unreadable and processing_error states
- Confirmed financial entries are locked and included in monthly reports and CSV exports
- PostgreSQL constraints and append-only audit/evidence history

## Getting started

Prerequisites: Ruby 3.2+, PostgreSQL 16+, libvips 42, Bundler.

1. Run bundle install.
2. Run bin/rails db:prepare.
3. Run bin/rails server.
4. Open http://localhost:3000/registration/new to create an account and private workspace.
5. Log in at /session/new to manage income and expenses.

Registration is enabled by default in development/test only. For production registration must be enabled explicitly with ENABLE_SIGNUP=true.

## Tests

Run bin/rails test and ruby tests/test_input_policy.rb. GitHub Actions also runs both against PostgreSQL.

## Item dates, tags and draft totals

Line items require verified dates. Draft transaction amounts synchronize with line-item changes; confirmed entries remain locked. Tags use /finance/tags. Income offers visible image-proof upload.

See [required dates and draft amount rules](docs/FINANCE_ITEM_DATE_TOTAL.en.md).

## Security and evidence

Only authorized workspace users can view financial data or images. Original document versions, AI runs and audit events are retained. Additional evidence may be attached after confirmation without changing the confirmed financial snapshot. Human confirmation is required before entry into any financial report.

The system never parses image text using handcrafted OCR or amount/date heuristics. Unknown values remain blank or require manual entry.

## Implementation status

This repository contains a functional Rails foundation, not a production accounting release. A live llama.cpp/GGUF adapter is not enabled; the available research model did not pass the difficult-handwriting quality gate. Inventory/sales fulfillment, statutory reversals, PDF exports, team membership and production hardening remain planned.


## Temporary Cloudflare Quick Tunnel preview

The development-only preview flag permits `*.trycloudflare.com` hostnames, suppresses detailed Rails debug errors, and disables public self-registration.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails server --binding 127.0.0.1 --port 3078
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:3078
```

Create a dedicated non-production preview account and use *synthetic* data only. Quick Tunnel URLs are temporary and not authentication. Production deployments must configure their own security and host policy. The GGUF inference adapter remains disabled in this preview.


## Dashboard, reports and language support

- Responsive finance workspace dashboard with four KPIs, transaction search, type/status filters and pagination.
- Expanded reports: previous-month comparisons, six-month trend, expense primary-Tag allocation, daily activity, recent confirmed entries and verified CSV export.
- English and Vietnamese interface switching with Rails I18n and a signed locale cookie. UI translations are stored in separate locale files; underlying financial data and CSV remain unchanged.
- Step-by-step in-app guide for manual input, evidence versioning, review and human confirmation.

**Details:** [Finance UX and reporting (English)](docs/UX_REPORTING.en.md).

The current Cloudflare preview remains limited to synthetic sample data; GGUF live inference is still disabled. The application does not claim production accounting compliance.


## Optional multi-month demo data

A development-only, idempotent script adds synthetic confirmed income and expenses for May–October 2026 to the existing dedicated demo workspace. It does not create a user, generate receipts, or alter existing transactions.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_reporting.rb
```

The script refuses production and requires the exact existing demo account/workspace. Run it manually, never from the default production seeds. All sample values are invented and must not be represented as actual financial history.


## Optional transaction details

The income/expense transaction date must be entered before confirmation. **Time of day and location are optional** and never inferred from EXIF, uploads or guessed OCR output. Every draft can also include a free-text explanation of what was purchased or paid for.

Context information is stored separately from the immutable financial ledger, with a linked actor and provenance. The content can be revised while the transaction is a draft; after financial confirmation, a database trigger prevents edits/deletion. The confirmed amount and accounting date are unaffected by supplemental explanations.

A dedicated development-only, idempotent seed script enriches previously confirmed **synthetic** demonstration entries without rewriting their financial records, and adds a 30,000 VND sample bakery purchase dated April 26, 2026 at 08:12. Some examples omit time or location to demonstrate optional fields.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/enrich_demo_transaction_contexts.rb
```

See [transaction context details (English)](docs/TRANSACTION_CONTEXT.en.md). CSV exports include optional purpose, time and location; reports still aggregate only confirmed transactions.


## Multi-line receipts and bulk imports (M6)

A single transaction can contain up to **500 itemized lines** with independent descriptions, amounts and optional quantity, unit price and Tags. The accounting total remains a separately **human-confirmed amount**, synchronized from human-entered draft line items on changes, but never inferred from untrusted OCR output.

For a small draft, use **Add another item** on the transaction form. For a long receipt, open **View and manage all items**, which paginates 25 rows at a time and permits editing or removing draft entries. Alternatively import a UTF-8 CSV with required `description,amount` and optional `quantity,unit_price,tags,occurred_time,location_text` columns, max 500 rows/512 KiB. Imports are atomic and SHA256-idempotent per transaction; changed CSV files append rather than overwrite.

Try [100-row example CSV](examples/receipt_lines_100.csv), or seed four **synthetic** 5/20/50/100-line demo receipts in an existing dedicated development demo workspace:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_itemized_receipts.rb
```

The reporting dashboard now has a separate confirmed primary-Tag allocation view and reconciliation difference; it never counts items again as standalone transaction totals. Stored model proposals can be reviewed in paged item groups, but they never auto-write finance data. **Live GGUF OCR import remains disabled pending separate model quality acceptance.**

See [M6 receipt workflows (English)](docs/MULTI_LINE_RECEIPT.en.md).


## Confirmed transaction corrections (M7)

When an item in a confirmed receipt is wrong, **do not edit the locked original**. Open the item list and select **Edit item details** on the affected row. Its modal requests a correction reason and creates a separate draft replacement. Its accounting date, amount, optional time/location and all line items (including 100-line receipts) are copied for editing. The original receipt images remain with the original record and can be opened through the link.

After explicitly confirming the replacement, financial reports and CSV use only the **effective confirmed transaction**, not both original and replacement. Each correction carries immutable provenance and an audit trail. Draft corrections never affect totals. This is a supersession workflow, not statutory double-entry accounting or a regulated reversal mechanism.

A development-only synthetic correction sample can be created from the 100-line demo receipt:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_correction.rb
```

More: [Correction workflow (English)](docs/CORRECTION_WORKFLOW.en.md). This workflow runs on CPU and does not enable the GGUF AI adapter.


## Shared transaction date, optional item times and places

Every item **uses the date of its parent transaction**, with optional item-specific time (HH:MM) and location. The item editor shows this date but never asks for a separate day or invents the current time. An undated draft can have items; the transaction date is required before confirmation. The legacy per-item date column is preserved, not backfilled or changed on confirmed originals. Item description, amount, quantity, unit price and Tags remain editable on drafts.

Open a draft transaction’s **item list** and select **Edit item details** on each row to open the Turbo modal. Saving successfully re-renders only the changed row and reconciliation summary without a full-page refresh. For confirmed items, the same modal asks for a reason and creates a correction draft without touching the immutable source. Original confirmed financial records remain unchanged. If an earlier correction exists, the list links to its replacement. The accounting date comes from the parent transaction. The parent draft amount synchronizes from the user-entered item sum when items change, while confirmed entries remain immutable.

Manual CSV imports need no independent item date and accept optional `occurred_time` (HH:MM) and `location_text`; legacy `occurred_on` may be supplied only when matching the parent date. See [item context CSV example](examples/receipt_lines_with_item_context.csv). To create five **synthetic editable draft items** sharing one date but varying times/locations in the dedicated development demo:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_individual_item_contexts.rb
```

More: [item-level context and editing (English)](docs/ITEM_LEVEL_CONTEXT.en.md).


### Compact item entry modal

On a draft item list, **+ Add a single item** opens a Turbo modal. A successful save re-renders the paginated item list and reconciliation summary, closes the modal, and displays a confirmation without a full-page refresh. Validation errors stay inside the dialog. CSV import is available from a collapsed toolbar disclosure. The established per-row edit modal and immutable confirmed records remain unchanged. See [multi-line receipts](docs/MULTI_LINE_RECEIPT.en.md).


## Bilingual Tags and unified transaction screens

The **Tags** navigation entry opens `/finance/tags`, providing workspace-scoped Tag creation, editing, archival and EN/VI labels. A Tag has a stable key and may be assigned to many transactions and line items. There are **no live category fields or category tables**: `finance_transactions.category` and `finance_line_items.category` were retired after a verified backfill into relational tag links, and `finance_categories` became `finance_tags`. Reporting uses only the first associated Tag for financial allocation so each transaction and line amount is counted **once** regardless of how many Tags it has.

The unified income/expense receipt-first intake has two radio options. New manual amounts become the first line item and are no longer independently editable as transaction totals. Draft edits can select multiple Tags; confirmed financial evidence is not overwritten. [Tags-only schema and migration specification](docs/TAGS_ONLY_SCHEMA.en.md) and [Tag management](docs/TAGS_MANAGEMENT.en.md).

## Upload-first receipt intake and review (M9)

The **Money out** entry flow places **Upload your receipt** first: select expense/income, choose or drag a JPEG/PNG/WEBP image (max 10 MB), then **Upload & continue**. This immediately creates an **unconfirmed draft**, preserves the original image and SHA256 provenance, and opens a dedicated receipt review page. Users do **not** type date, total or individual items before uploading. A collapsed manual form remains available when there is no image.

The review page shows the actual receipt, editable transaction details and the per-item editor. **The GGUF vision adapter is not connected in the current CPU preview**: uploading does not execute AI inference or invent extracted fields. Existing model suggestions, if independently recorded, are displayed as unconfirmed suggestions. A separate human action is always required to confirm financial records.

See [receipt-first workflow and AI boundaries (English)](docs/RECEIPT_FIRST_WORKFLOW.en.md).


## Unified income and expense intake (M10)

The `/finance/transactions/new` form serves both **Money in** and **Money out** through two radio controls and a shared upload-first layout. A manual amount is entered as the first line item; optional transaction Tags and images can be added without creating a second record. Draft-only edits require human verification, and confirmed financial records remain immutable. Image upload works, but **live GGUF inference is not connected**. [Current unified intake policy](docs/UNIFIED_INTAKE_TRANSACTION_REVISIONS.en.md).

## Fast item modal, automatic totals and multi-tags (M11)

The receipt-item popup defaults **quantity to 1** and displays the **shared transaction date** without offering a line-level date input. An unknown draft date stays unknown; no present-day or current-time fallback is fabricated. Item time and location are optional, and the transaction date is edited on the parent. Changing quantity or unit price updates the line total immediately with JavaScript and Rails independently recalculates the total on submission. Without a price, a manual amount can still be entered; the draft parent amount is synchronized to the human-entered line sum with audit.

Each item can have **multiple Tags** selected as chips, and users can enter new comma-separated tag names in the same modal. Tag creation and item updates are atomic, workspace-scoped and protected against confirmed-ledger changes by a PostgreSQL trigger. There is no single-category field; a one-row-per-ledger-entry primary-Tag allocation keeps financial reporting free of double-counting. The Tags catalog stores independent EN/VI names. [Fast item and multi-tag workflow](docs/QUICK_ITEM_TAGS.en.md).


### Item dialog interaction refinement (M11)

The Add/Edit receipt-item modal now uses a centered SVG close icon, a consistent outlined Cancel action, and **explicit dismissal only**. Clicking the overlay or pressing Escape does not discard an unfinished form; users click Close or Cancel. Successful save still closes the popup through the existing Turbo Stream and refreshes the relevant item/summary. The Tags sidebar uses a separately styled activation checkbox rather than wide text-input CSS.


### Responsive item cards on smaller screens

The receipt-item manager keeps its six-column table on wide screens but switches to readable, responsive cards below 1,200px: amount, description, tags, date/time/location and full Edit/Delete buttons remain visible without horizontal scrolling. One row retains one stable Turbo Stream DOM ID, so edit updates and pagination remain compatible. See [quick item and tag documentation](docs/QUICK_ITEM_TAGS.en.md).

## One income/expense intake and revision history

Create both Money in and Money out at **`/finance/transactions/new`**, selecting exactly one radio above the existing receipt-first upload and manual fallback. Legacy `?kind=` URLs select the radio without changing layout. Draft edits require a written reason and store immutable, numbered before/after revisions with timestamps and actor. Confirmed ledger values are never overwritten: creating a correction starts a separate draft, preserves the original and records correction lifecycle revisions; reports count only the effective confirmed version.

[Unified intake and transaction revision policy](docs/UNIFIED_INTAKE_TRANSACTION_REVISIONS.en.md).

## Correction draft cancellation, locked totals and transaction Tags

Pending correction copies can be **discarded with a mandatory reason**, with both the original financial record and cancellation history preserved. Draft totals are read-only and calculated from human-authored item amounts; new app-created drafts require at least one item to confirm, while historical legacy amounts are preserved. Transactions now support multiple workspace-scoped Tags, just like individual items, and replacement drafts clearly identify and compare themselves against their locked originals. See [complete policy and constraints](docs/CORRECTION_DRAFT_TAGS_LINE_TOTAL.en.md).

The correction draft now offers a read-only original-transaction popup on both edit and detail screens, preserving unsaved fields. Discard is distinctly red, and the redundant Manage Tags link was removed from the transaction form.

The correction comparison banner distinguishes draft, confirmed and cancelled replacements by their actual status, and original-view modal controls have accessible, responsive neutral styling.

Correction item differences now open in a focused read-only modal; the redundant aggregate comparison heading has been removed, while the financial before/after fields remain visible.

Minor UI updates (2026-10-31): expense-item modal labels the description **Reason for expense**, receipt-review action is reserved for receipt-first drafts, and monthly income/expense KPI arrows are swapped. [Details](docs/FINANCE_UI_REFINEMENTS_20261031.en.md).

Evidence UX (2026-10-31): transaction detail pages show responsive thumbnails of stored receipt versions and their SHA256, with authenticated original-image access. [Details](docs/RECEIPT_VERSION_PREVIEW_20261031.en.md).

Date-range filters (2026-10-31): both Transactions and Reports support inclusive From/To dates and shared quick presets (week, first/last two weeks, previous month, etc.), with consistent financial aggregates and CSV export. [English guide](docs/DATE_RANGE_FILTERS.en.md).

The shared date-range filter now uses a responsive report grid and explicitly distinguishes unsubmitted date selections from the applied server range, including browser history restoration.

Transactions History and Reports additionally support tenant-safe multi-Tag OR filtering across transaction and line-item Tags, preserving date filters in CSV/navigation. The Report-to-History link is now a responsive, styled button. See [date and Tag filtering](docs/DATE_RANGE_FILTERS.en.md).

Tag-filtered monetary reports now attribute **only matching line items** when no direct transaction Tag matches; original transaction amounts remain immutable and are displayed separately. CSV adds `MatchedTagAmount` for exact reconciliation.

Item sorting (2026-10-31): itemized transaction pages allow read-only original-order, name, amount, time and location sorting in either direction, through clickable desktop table headings and stable pagination (no separate sorting control panel). [Guide](docs/LINE_ITEM_SORTING.en.md).

The shared transaction date is displayed once above the itemized list instead of repeating in every item table row/card. The six-column table and its sorting behavior remain unchanged.

Item filtering (2026-10-31): the transaction itemized list supports case-insensitive item-name search, inclusive HH:MM time and amount ranges, item-level multi-Tag OR selection, and combined filtering before sorting/pagination; full ledger totals remain unchanged. [Guide](docs/LINE_ITEM_FILTERING.en.md).
