# Receipt-first intake and human review (M9)

## User journey

The Money out (expense) entry screen at `/finance/transactions/new` now begins with uploading a receipt photo (JPEG/PNG/WEBP, 10 MB maximum). The user selects expense or income, chooses the image from a device or drops it into the upload area, and presses **Upload & continue**. No date, amount, description, category, merchant or item is required before upload. A local browser-only preview shows the selected file; it never analyzes the photo.

`POST /finance/transactions/from_receipt` calls `Finance::ReceiptIntake`. It creates an **unconfirmed, empty financial draft** and stores the uploaded image via the existing `Finance::UploadDocument` validation pipeline, with the original image, SHA256, MIME, file-size and document-version provenance. The request is transactional: an invalid or unsupported image rolls back the new financial draft. No financial fields are fabricated, the original image is not modified, and receipt uploads never enter confirmed reports.

After upload, users land at `/finance/transactions/:id/review`. This page shows the actual image, the draft fields (date, amount, description and category), optional context, any existing AI suggestions, and links to the familiar per-item modal editor. Saving fields returns to review. Only a separate, explicit confirmation action can make the transaction reportable. Uploading multiple images after draft creation remains available from its transaction detail page.

## Current AI boundary (important)

**Uploading a receipt does not yet execute Qwen3-VL GGUF inference in this Rails demo.** The GPU is intentionally off. No automatic extraction results, progress spinner, inferred totals or merchant names are invented. The review screen clearly states that the vision adapter is not connected when there are no persisted model suggestions. If independently recorded model suggestions exist, they are displayed as **unconfirmed evidence only**, never auto-posted to financial fields. The project policy forbids image-specific OCR heuristics or hard-coded text/date/amount parsing. Unreadable data remains unknown/NULL and needs a clearer image or human input.

This is a functioning **upload-first and human-review experience**, not a claim that real-time extraction is now active. Full automation requires an authenticated, verified GGUF adapter, audited prompt/model SHA256 and field-level acceptance tests.

## Manual fallback

The upload screen keeps the manual form collapsed under **Enter without a receipt**, which creates an ordinary draft. Neither flow changes immutable confirmed records, tenant isolation, category localization or financial-report arithmetic.

## Verification

Integration tests check the primary upload UI in EN/VI, original image persistence, provenance and audits, rollback on invalid images, review editing, no premature confirmation, workspace isolation and fallback manual create.
