# Independent item date, time and location

Each `finance_line_items` row has its own **optional** `occurred_on` (ISO calendar date), `occurred_time` (local wall-clock HH:MM) and `location_text` (free text, up to 400 characters), as well as a description/label, amount, category and optional quantity/unit price. All three contextual columns are nullable. They are **not** filled from the transaction date, photo metadata or any unrelated item. Time does not imply a verified timezone. The accounting transaction date is a distinct mandatory field when confirming.

An item can be documented as a synthetic example: "Sweet bread · 30,000 VND · 2026-04-26 · 08:12 · Example bakery near a police station in Da Nang". Another item on the same transaction can have a different date, time, location or none. Example names and places are fictitious and must not be represented as verified merchants.

## How to edit

For a **draft transaction**, open `/finance/transactions/:transaction_id/line_items` and select the prominent **Edit item details** button on its row. A Turbo/Stimulus modal lets users change the item label, price, quantity, unit price, category, date, time and place; blank fields remain null. Edits are logged in the transaction audit. The parent transaction amount does not silently change when a line price is edited, so reconcile totals before confirming.

For a **confirmed transaction**, the original item is immutable. Select **Edit item details** on the row; the same modal requires a correction reason. Saving creates an auditable correction draft with all items cloned and applies the edited fields to the selected copy. The original row updates to link to the replacement draft, which must be separately confirmed. The original receipt stays available. Only after explicit confirmation does the replacement become effective in reporting. If the original already has a correction, the row links to the existing replacement instead. Turbo Streams replaces only the affected row and reconciliation summary, closes the modal and displays a status message; invalid data keeps the modal open. The obsolete correction/new GET page is no longer used.

## Manual CSV import

`description` and `amount` remain required. All other optional columns include `quantity`, `unit_price`, `category`, `occurred_on`, `occurred_time` and `location_text`. Date must use `YYYY-MM-DD`; time must use 24-hour `HH:MM`; unknown values must be empty. Invalid CSV values reject the whole import. No OCR parser or image-specific heuristics are used.

Use [example CSV](../examples/receipt_lines_with_item_context.csv). For a **development-only draft** with five distinct purchases, run:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_individual_item_contexts.rb
```

The five purchases deliberately contain both populated and missing contextual fields. This is synthetic sample data and stays in draft for safe interactive editing.
