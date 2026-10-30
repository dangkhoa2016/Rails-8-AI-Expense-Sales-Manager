# Shared transaction date and audited draft totals

## One accounting date

A transaction owns **one date**, stored as `finance_transactions.transaction_date`. Every line item displays this date; the add/edit item modal does not offer an independent date field. A draft may have no date while details are being entered, but the transaction date must be provided before the user can confirm it. Optional `occurred_time` (HH:MM) and `location_text` remain per-item; neither is guessed or prefilled from the current clock.

For new line items, the deprecated `finance_line_items.occurred_on` remains NULL. Historical values (including values that differ from the parent date) are **not rewritten**; confirmed originals and correction provenance remain intact. The effective accounting date comes from the parent transaction, even when the historical line-item column contains an old value. Editing the parent draft date changes the displayed date for all its items.

## Manual entry and CSV

New CSV files require only `description,amount`; optional headers include `quantity,unit_price,category,occurred_time,location_text`. For compatibility, older CSV files may still include `occurred_on`, but any nonblank date must be a valid ISO date matching the transaction date. A conflict rejects and rolls back the entire import instead of discarding evidence silently. Imported lines do not persist an independent date. CSV SHA256 replay protection remains in effect. No image OCR parsing or date heuristics are used.

## Draft totals and immutability

Adding, editing, deleting or importing draft line items synchronizes the parent draft amount to the line sum, **including zero after deleting the last item**. New app-created transactions require at least one line and matching total before confirmation. Existing legacy transaction amounts and confirmed originals remain untouched; no historical line items are fabricated. See [locked totals and correction cancellation](CORRECTION_DRAFT_TAGS_LINE_TOTAL.en.md).

## Tags and income evidence

The canonical Tag management URL is `/finance/tags`; the legacy `/finance/categories` URL remains for compatibility. Duplicate Tag keys show localized field-validation errors in English and Vietnamese instead of “Translation missing”. The income proof-image upload stays available without activating GGUF inference.

## Verification boundary

Regression tests cover the shared date, optional time, old CSV validation, atomic rollback, duplicate Tag messages, audit and confirmed immutability. Live GGUF quality and manual responsive browser QA are not included.
