# UX and Financial Reporting — English

## Transaction workflow

Transactions provide a current-month overview of confirmed income, confirmed expenses, net cash flow, and pending drafts. The table supports tenant-scoped search, status/type filters, and pagination.

The user may create income or expense drafts without uploading a receipt. Financial confirmation requires a user-verified transaction date and a positive amount. Confirmed entries cannot be silently updated. Receipt uploads remain separate immutable evidence versions with SHA256, including supplemental evidence after confirmation.

## Monthly analytics

Choose a reporting month to see four KPIs: income, expenses, net cash flow and confirmed transaction count. Income and expense cards show previous-month totals for context. The six-month trend and daily activity group by the **human-confirmed transaction date**, not upload or creation timestamps. Category bars represent confirmed expenses for the selected month. Recent entries link back to original transaction details and evidence.

CSV exports contain only confirmed entries in the active workspace, preserve raw numeric values, and guard against spreadsheet formula injection. Drafts and AI-only field proposals never enter totals.

## Languages and usability

Switch EN / VI in the header. Rails I18n translations are maintained in separate `config/locales/en.yml` and `config/locales/vi.yml` files. Language preference persists using a signed cookie. Display formatting changes with the locale; stored amounts and dates do not.

The Guide page explains manual fallback, document versioning, per-field proposals, explicit confirmation, audit and report scope.

## Limits

GGUF inference remains disabled until quality gates pass. This is not a production accounting or inventory release. PDF/yearly exports, locale-specific fiscal policies, user roles and correction workflows remain future work. Temporary Cloudflare tunnels are for synthetic demo data only.
