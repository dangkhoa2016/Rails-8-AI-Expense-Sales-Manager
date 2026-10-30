# M7 — Auditable financial correction workflow

> **Current schema note (2026-10-30):** References to single-category fields below describe historical milestones. The current application uses Tags only; see [Tags-only specification](TAGS_ONLY_SCHEMA.en.md).


## Problem and invariant

Confirmed transactions and their line items remain immutable, even when a user notices an incorrect amount, transaction date, description or receipt item. An in-place edit would compromise the audit trail.

A correction creates a **separate replacement transaction in draft state** and a `finance_corrections` link. The original remains confirmed, with all financial values, images, extraction evidence, and audit records intact.

## User flow

1. On an already confirmed transaction, open its item list and choose **Edit item details** on the affected row. The modal requires a reason (10–2000 characters).
2. Saving the modal copies the original date, amount, type, description, category, optional time/place/context, and all line items into a *new draft*, applying the changed fields only to the selected copied item. Original receipt versions stay attached to the original; the replacement links back to that record for access to evidence.
3. Review and edit the draft's details and item list through the same per-item Turbo modal. A 100-item receipt is supported.
4. Explicitly confirm the replacement. The old and replacement entries remain confirmed and immutable, but the correction now says which record is effective.
5. Reports, monthly trends, category allocations and CSV exports select **effective confirmed transactions only**. The original is no longer counted; the replacement is counted once.

A correction draft has no effect on financial summaries. Duplicate corrections of the same source are blocked. A subsequent correction of the replacement is possible as a linked chain. Neither AI review nor an image upload automatically authorizes a correction.

## Technical model

- New `finance_corrections`: unique `original_transaction_id`, unique `replacement_transaction_id`, workspace, actor, reason, status, confirmation actor and timestamps.
- PostgreSQL CHECK constraints, foreign keys and a trigger prevent mutation/deletion of already confirmed correction records or reassignment of their provenance.
- Creation and confirmation are wrapped in database transactions with row locking.
- Finance::Transaction.effective_confirmed excludes confirmed correction source IDs.
- The original's immutable audit trail gains append-only correction requested/superseded events. The replacement gains its own audit trail.

## Scope and limitations

This is a **replacement/supersession** mechanism rather than a regulatory reversal or journal-entry double-entry accounting system. The application does not calculate tax corrections or issue tax invoices. Dedicated role-based approval, correction cancellation, tax-compliant audit exports and production security review remain future milestones. Use synthetic examples in the temporary demo.
