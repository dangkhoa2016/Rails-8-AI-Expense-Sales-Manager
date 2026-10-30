# Transaction date with optional line-level time and location

> **Current schema note (2026-10-30):** References to single-category fields below describe historical milestones. The current application uses Tags only; see [Tags-only specification](TAGS_ONLY_SCHEMA.en.md).


Each item belongs to one `finance_transactions` record, and **inherits its effective date from `transaction_date`**. The item editor shows the shared date but does not accept a line-level calendar input. A missing date on a draft is not replaced with today's date. The parent date must be reviewed before confirmation. An item may store its own optional local `occurred_time` (HH:MM) and optional `location_text` (up to 400 characters). Different times within one transaction are possible but not required or assumed.

The deprecated `finance_line_items.occurred_on` column is retained **read-only in user workflows for historical provenance**. New manual, nested and CSV items leave it NULL. Existing confirmed items may contain old dates different from the parent date; those original values are preserved without destructive backfill. Display uses the parent transaction's effective date, while corrections clone historical source values for audit purposes.

## Item editing and corrections

Open `/finance/transactions/:transaction_id/line_items`. A draft item's **Edit item details** modal edits description, amount, quantity, unit price, category/tags, optional time and location. Draft financial totals synchronize after changes and are audited. Changing the date requires editing the **transaction** rather than the item.

Confirmed records cannot be overwritten. Their edit action requires a correction reason and creates an editable replacement draft; source data stays intact. The original is superseded in reports only after explicit human confirmation of the replacement. A second correction is prevented when one already exists.

## CSV import

Required headers: `description,amount`. Optional: `quantity,unit_price,category,occurred_time,location_text`. For compatibility, the historical `occurred_on` header is accepted only if each supplied nonblank value matches the stored parent transaction date; mismatch or malformed date rejects the entire batch. Unknown time/location may be blank. No image parser, OCR heuristics or fabricated dates are used.

[Example CSV](../examples/receipt_lines_with_item_context.csv). To create a development-only five-item example with one shared day and different optional times/locations:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_individual_item_contexts.rb
```

The script is opt-in, uses fictional data, and does not alter existing confirmed records or previous demonstration drafts.
