# Historical two-journey design (M10)

**Current behavior (2026-10-30):** M10's separate entry layouts were superseded by one receipt-first `/finance/transactions/new` page with Money in/Money out radio controls. Editing transaction amounts and single-category dropdowns were also replaced by a locked, line-item-derived total and multi-select Tags. The following sections document the earlier design for historical context, **not the current UI**. See [unified intake](UNIFIED_INTAKE_TRANSACTION_REVISIONS.en.md) and [current finance corrections/Tags policy](CORRECTION_DRAFT_TAGS_LINE_TOTAL.en.md).

## Design goal

The expense and income experiences are intentionally different, while sharing typography, navigation, validation, and safe financial posting. The interface no longer treats a single generic multi-field form as the only starting point. Existing ledger columns are **not dropped or rewritten**. Confirmed transactions remain immutable, with corrections handled through separate auditable drafts.

## Money out — expenses

Open `/finance/transactions/new?kind=expense` (or the Money out tab). The primary action is **upload a receipt**. The original JPEG/PNG/WEBP is stored as a versioned, SHA256-verified document, and an amount-free, date-free draft is created before any field is accepted. The expense review page displays the actual image and only date, amount, description and an optional category. The remaining receipt items are managed through the existing per-item Turbo dialogs with the shared transaction date and optional per-item time/location.

If the user has no image, a collapsed **quick manual expense** alternative asks for the amount and purpose. Actual date and category are in an optional disclosure. The accounting date and positive amount are still required before final confirmation.

## Money in — income

Open `/finance/transactions/new?kind=income` (or the Money in tab). The primary card is **quick income**: amount received, description/source and actual date. All three must be valid for this quick-entry action; no inferred date or amount is inserted. Category is optional and collapsed. An expanded proof-image upload panel displays the file picker and drop zone by default, using the same upload pipeline as expenses. This creates an empty income draft without inferring an amount or date. Evidence can also be attached **to an existing income draft** from the income review screen, without generating a second transaction.

The income review page centers on amount, source and date; item breakdown is optional. Draft line-item changes synchronize the draft transaction amount to the remaining lines, with audit; the user may still override and reconcile before confirmation.

## Context and AI

The UI does not ask users to duplicate transaction-level place/time/purchase-detail fields during normal entry. Legacy values remain stored and accessible through the established draft-edit and record paths. A category key remains stable and translatable via workspace-scoped EN/VI names.

The currently deployed CPU demo has **no live Qwen3-VL GGUF adapter**. Uploads do not extract or invent invoice details. Any existing persisted AI proposals are labeled as unconfirmed, and human confirmation is separate. This work improves the interaction pattern but does not claim working automatic image recognition.

## Compatibility and validation

All forms use the existing authenticated workspace, draft validation and audit model. The income quick-entry controller validates positive amount, date and source even if HTML validation is bypassed. The receipt upload path continues to reject unsupported/corrupt images atomically. Existing transaction reports, API routes and historical data remain intact; the shared URL chooses the mode from `kind=expense` or `kind=income`.

Integration tests cover VI/EN mode switching, independent form structure, quick income validation, receipt-first expenses, optional income proof, draft review screens and the immutable confirmation gate.
