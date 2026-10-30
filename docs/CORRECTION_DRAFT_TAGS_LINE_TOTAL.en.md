# Correction draft cancellation, locked totals, transaction Tags, and original comparison

## Scope and invariants

A confirmed transaction remains an immutable financial source. A correction creates a separate editable draft, preserves its relationship to the source and does not change reporting until a human confirms it. The accounting date remains on the parent transaction; every item inherits it. No image-reading heuristics, estimated amounts, OCR parser or new GGUF inference are introduced by this change.

## Cancel a correction draft

Open a pending replacement's detail page and choose **Discard this draft**. Provide a reason between 10 and 2,000 characters and confirm the operation. The system changes the correction and replacement statuses to **cancelled**, adds append-only audit events on both records, and records a new source revision with the cancellation reason, actor, time and linked correction ID. The original confirmed transaction, original documents, original amounts and original line items are never modified. The replacement is no longer shown in the active transaction list and cannot be edited, confirmed, or uploaded to, but remains available by direct authenticated URL for investigation. Database triggers guard cancelled transactions, items, context and tag links from modification. This is a **soft deletion**, not a hard delete. A new correction may be started for the same source after the previous pending copy is cancelled; earlier cancellation history remains.

Only draft corrections can be discarded. Confirmed corrections are immutable and cannot be cancelled through this route. Workspace authorization is enforced for both operations.

## Transaction total is derived from items

The edit and receipt-review forms no longer provide an editable transaction amount. The total is displayed as read-only and changed only by adding, editing, importing or deleting line items. A new manual entry's amount is explicitly treated as its **first line item**, and line-item changes synchronize the draft parent amount. Deleting the final line sets the draft total to zero. New app-created drafts are marked `line_total_managed=true`; confirmation requires at least one item and exact agreement between item sum and transaction amount.

**Legacy exception:** Existing transactions migrated from earlier versions have `line_total_managed=false` and keep their historical recorded amounts, even when there is no breakdown. They are not backfilled with invented lines, and confirmed originals are never recalculated. A legacy correction with no source items retains its source amount until user-entered lines exist. This exception is intentional and visible; it does not authorize backfilling or rewriting historical financial evidence.

No item total is inferred from an image. User verification remains mandatory.

## Multiple Tags for a transaction

The transaction edit and review forms now show the same workspace-scoped multi-select Tags UI as line items. Users may select multiple existing Tags or enter new comma-separated names. Newly typed labels are saved as user-authored names, not automatically translated. The first selected Tag remains the existing single primary `category` reporting key internally; secondary Tags are labels and must **not** multiply totals in reports. Existing tag keys and localized names are preserved; archived Tags cannot be newly attached, though historical associations remain visible. A dedicated join table has tenant-scoped model validation, a unique constraint and PostgreSQL triggers preventing modifications outside an editable draft. Correction copies retain their Tags. Updating Tags is captured in transaction revision snapshots and before/after history.

## Correction origin and comparison

Both the replacement edit form and detail page show an unmistakable **Correction draft — copy of locked original** banner, a link to the source and an original-versus-replacement summary. The expanded comparison lists changed date, amount, description, primary classification, Tags and item details; a 100-item correction remains navigable via a collapsed list of only the differing items. The summary updates as the replacement is edited. The original remains read-only and the replacement affects reporting only after explicit confirmation.

## Review and evidence

Use test migrations and integration/browser tests before applying the migration to a preview database. Verify cross-workspace isolation, immutable cancelled copies, cancellation/restart behavior, total locking, last-item deletion, multi-Tag selection, and the source comparison. Archive backups and audit logs before changes. The demo environment is not production accounting and AI GGUF vision inference is not enabled.
