# Optional transaction details — English

The date of an income/expense transaction remains mandatory **when confirming**. The time of day and the place are optional. Users may still save drafts with missing dates and create entries entirely by hand without a receipt or model inference.

## Structured values

- `finance_transactions.transaction_date`: date of the income/expense entry, confirmed by the user.
- `finance_transaction_contexts.purchase_details`: what was purchased, paid for, or sold. Optional supporting explanation.
- `finance_transaction_contexts.occurred_time`: optional local wall-clock time (PostgreSQL `time without time zone`, displayed as HH:MM). No timezone, GPS, upload timestamp or EXIF assumptions are used.
- `finance_transaction_contexts.location_text`: optional user-entered free-text location, not a geocoded or verified address.
- `finance_transaction_contexts.source`: `manual` or `demo_seed`; users cannot set source via form parameters.
- `recorded_by_id`: actor attribution. A unique foreign key links each context row to a single transaction.

Forms create or edit context on draft transactions only. After confirmation, the context is locked in Rails and PostgreSQL. Previously confirmed records may receive a **one-time, attributed append-only supplemental context** for the demo; the original ledger row, amount, date, status and confirmation audit are not modified. A trigger prevents changing or deleting that context once the financial entry is confirmed.

## Example scenario

An illustrative manual expense can contain:

- Date: 2026-04-26
- Description: Sweet bread for breakfast
- Amount: 30,000 VND
- Time: 08:12 (optional)
- Place: A **fictional demo bakery** near a police station in Da Nang (optional)

The displayed venue is example text only. It is not evidence a real shop exists at that address or that an actual purchase occurred.

## Private demo dataset

After setting up an existing dedicated development preview account, run:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_reporting.rb
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/enrich_demo_transaction_contexts.rb
```

The second command verifies all 28 pre-existing demo records against their dates and amounts, appends contextual sample text exactly once, and creates the example bakery expense with one line item before human-style demo confirmation. Repeated runs must be idempotent; conflicts fail rather than overwrite context. The script refuses production and does not create accounts.

The detailed context and optional time/location are also exported as three extra columns in the **confirmed-only** CSV, with protection against spreadsheet formulas. All financial summaries remain calculated solely from the original confirmed amount and transaction date. No real receipts or AI OCR values are required.
