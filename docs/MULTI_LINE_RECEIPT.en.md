# M6 — Multi-line receipts and bulk import (English)

## Data model

One income/expense transaction can have **0–500 individual line items**. These are not 500 separate accounting postings. The parent `finance_transactions.amount` and `transaction_date` are human-confirmed accounting values; items are a breakdown (item description, amount, optional quantity/unit_price/category). Time/location remain optional transaction-level context.

The parent amount is **never inferred** from item subtotals or from a receipt. The item breakdown total is compared with the parent amount; differences may represent VAT, discounts, fees or unreadable/missing items. Confirmed-ledger reports count each parent transaction **exactly once**. A separate item-category allocation report uses item subtotals only, shows its difference to the confirmed expense total, and never adds allocations again to income/expense totals.

## Manual entry and bulk CSV

Small drafts support a dynamic **Add another item** button via Stimulus. Larger receipts use the paginated Item Manager (25 rows/page) to edit individual descriptions, category, amount, quantity and unit price. A draft can store many items even if the main form intentionally avoids rendering 100 nested inputs at once.

Use the sample CSV at `examples/receipt_lines_100.csv`, or provide a UTF-8 CSV with required headers:

```csv
description,amount,quantity,unit_price,category
Sweet bread,30000,2,15000,food
Printing paper A4,85000,1,85000,office
```

Optional headers: quantity, unit_price, category. Other headers and duplicate headers are rejected. Requirements: positive quantity if present, nonnegative decimal unit price if present, amount with up to two decimals, positive or zero, description nonempty and at most 500 characters. Input limit: 512 KiB and 500 rows per CSV, with a maximum of 500 items per transaction. Decimal dots are required in CSV for machine readability.

The import validates the **entire** file first and writes the items, SHA256 import-batch record and audit event atomically under a transaction lock. Failure rolls back everything. Identical uploaded CSV bytes cannot import twice into the same transaction. CSV import is allowed only in an authenticated workspace **while the parent is a draft**.

Reimporting a modified CSV is a new batch, so it **appends** rows; edit/delete existing draft lines in the item manager to replace them instead. Imported quantity and unit price do not compute or overwrite the supplied line amount.

## AI review and safety

The existing pinned llama.cpp/GGUF OCR research pipeline is **not enabled** for this demo. If structured model output has already been saved in an extraction run, the Line Proposals page can display at least 100 proposed item groups, paginated, with accept/reject actions per proposed field. These reviews **do not create** line items or post a transaction. The user must verify and enter/import numeric data manually. No handwritten OCR heuristics, regex reconstruction from image, guessed dates or calculated image totals are permitted.

## Demo and checks

An opt-in demo seed generates **four synthetic receipts with 5, 20, 50 and 100 lines**, no authentic receipt files:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_itemized_receipts.rb
```

The script requires an existing dedicated demo account, refuses production, and is idempotent. The 50-row receipt intentionally includes a small synthetic reconciliation difference; the 100-row receipt balances. It does not rewrite previously confirmed records or introduce real financial information.

```bash
bin/rails db:prepare
bin/rails test
ruby tests/test_input_policy.rb
```

**Out of scope:** live AI image-to-100-line extraction, provider model quality acceptance, production accounting/reversal, allocation of shared VAT/discounts among lines, and large-scale async import jobs. These should only be claimed after separate evidence and testing.


## Compact add-item modal

The item list now has a compact toolbar rather than a permanently visible single-item form. **+ Add a single item** opens a Hotwire/Turbo Frame dialog with all the familiar fields (description, amount, quantity, unit price, category, optional item date/time/place). The CSV import remains available inside a collapsed disclosure control; AI proposals remain a separate link.

A successful Turbo Stream create updates the paginated item list, item-count/subtotal/reconciliation summary, closes the dialog and shows a confirmation without a full-page reload. If the newly added item falls on another page, a direct link to the last page is shown instead of overflowing the current 25-row table. Validation errors keep the modal open and preserve its fields. Confirmed transactions and other workspaces cannot add items. The parent accounting amount is never auto-adjusted.
