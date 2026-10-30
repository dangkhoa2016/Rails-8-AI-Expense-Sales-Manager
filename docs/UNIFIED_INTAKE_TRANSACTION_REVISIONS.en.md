# Unified income/expense intake and auditable transaction revisions

## One intake screen

Use **`/finance/transactions/new`** for both Money in and Money out. The page uses one receipt-first layout and exactly two radio choices. The selected kind is passed by the image-upload and manual-entry forms; changing the radio **does not navigate away or discard data already entered**. Older `?kind=income` and `?kind=expense` links remain valid as selection presets, not separate pages.

Proof upload stores an unconfirmed draft and original image (with SHA256). It never invents AI/OCR text or financial fields. Manual expense entry can start with incomplete draft fields; manual income retains server-side verification of amount, source and date. On income selection, the optional-details disclosure opens so the required transaction date is visible.

## Edit / revision contract

A draft transaction can be edited through its normal form or image-review form. Every edit submission must include a **human-written reason (10–2,000 characters)**. Actual changes to transaction fields and optional context create an immutable, numbered revision. Its timestamp is stored by the database in UTC, shown in the UI with date, seconds and Asia/Ho_Chi_Minh timezone. Every revision has the authenticated user, workspace, action, reason, before/after snapshots and a structured changed-fields payload. A repeated save with no changes does not create a fabricated revision. An optional optimistic-lock version protects against overwriting edits made since the form was opened.

The new `finance_transaction_revisions` table and its database UPDATE/DELETE denial trigger enforce append-only evidence. Revisions are workspace-bound in application code, numbered per transaction and created atomically with the draft update. Earlier audit events remain available and are not retrospectively called revisions.

Revision snapshots include the transaction's type, day, amount, description and category; contextual details; and the current line-item breakdown with tags. The history screen lists the changed groups and expandable before/after values. Separate line-item add/edit/delete and CSV operations continue to have their own existing audit events; a per-item operation alone does **not** create a new transaction revision in this release.

## Confirmed records

Confirmed financial records are **not** edited in place. The detail page offers a reason field for **Create correction draft**. A replacement draft copies the source transaction, line items and context. The source retains immutable original amounts, evidence and its own correction-request revision linked to the replacement. Editing the replacement draft records its revisions; separate explicit confirmation adds a correction-confirmed revision to the source, including the effective replacement state. Reporting continues to count only the effective confirmed transaction, avoiding double counting.

A confirmed transaction can have only one outgoing correction. Existing immutable PostgreSQL triggers, workspace boundaries and confirmation rules remain intact. The source images are not moved or rewritten.

## Validation and boundaries

Automated tests cover both radio modes, manual and image flows, drafts with required reasons, before/after states, version sequence, no-op edits, stale conflicts, cross-tenant denial, immutable DB records and the confirmed correction chain. Browser tests must verify radio switching and mobile layout after deployment.

The demo does not contain an enabled GGUF vision adapter. This implementation does not claim production accounting certification or automated financial extraction.
