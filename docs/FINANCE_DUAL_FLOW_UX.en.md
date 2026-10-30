# Two tailored financial journeys (M10)

## Design goal

The expense and income experiences are intentionally different, while sharing typography, navigation, validation, and safe financial posting. The interface no longer treats a single generic multi-field form as the only starting point. Existing ledger columns are **not dropped or rewritten**. Confirmed transactions remain immutable, with corrections handled through separate auditable drafts.

## Money out — expenses

Open `/finance/transactions/new?kind=expense` (or the Money out tab). The primary action is **upload a receipt**. The original JPEG/PNG/WEBP is stored as a versioned, SHA256-verified document, and an amount-free, date-free draft is created before any field is accepted. The expense review page displays the actual image and only date, amount, description and an optional category. The remaining receipt items are managed through the existing per-item Turbo dialogs with independent optional date/time/location.

If the user has no image, a collapsed **quick manual expense** alternative asks for the amount and purpose. Actual date and category are in an optional disclosure. The accounting date and positive amount are still required before final confirmation.

## Money in — income

Open `/finance/transactions/new?kind=income` (or the Money in tab). The primary card is **quick income**: amount received, description/source and actual date. All three must be valid for this quick-entry action; no inferred date or amount is inserted. Category is optional and collapsed. A secondary disclosure allows creating an image-first income draft when the user only has evidence and not yet verified amounts. Evidence can also be attached **to an existing income draft** from the income review screen, without generating a second transaction.

The income review page centers on amount, source and date; item breakdown is optional. The accounting amount is never silently recalculated from items.

## Context and AI

The UI does not ask users to duplicate transaction-level place/time/purchase-detail fields during normal entry. Legacy values remain stored and accessible through the established draft-edit and record paths. A category key remains stable and translatable via workspace-scoped EN/VI names.

The currently deployed CPU demo has **no live Qwen3-VL GGUF adapter**. Uploads do not extract or invent invoice details. Any existing persisted AI proposals are labeled as unconfirmed, and human confirmation is separate. This work improves the interaction pattern but does not claim working automatic image recognition.

## Compatibility and validation

All forms use the existing authenticated workspace, draft validation and audit model. The income quick-entry controller validates positive amount, date and source even if HTML validation is bypassed. The receipt upload path continues to reject unsupported/corrupt images atomically. Existing transaction reports, API routes and historical data remain intact; the shared URL chooses the mode from `kind=expense` or `kind=income`.

Integration tests cover VI/EN mode switching, independent form structure, quick income validation, receipt-first expenses, optional income proof, draft review screens and the immutable confirmation gate.
