# Rails 8 AI Expense & Sales Manager

Ruby on Rails 8 and PostgreSQL application for human-verified income/expense tracking, receipt image history and financial reporting.

Vietnamese: [README.vi.md](README.vi.md)

## Features

- Rails 8 authentication with private, per-account workspaces
- Manual income and expense drafts, with or without receipt images
- User-confirmed transaction dates and amounts (never inferred from upload timestamp or EXIF)
- Receipt versions stored privately in Active Storage with SHA256 and upload metadata
- Independent AI extraction runs and per-field proposals; no automatic financial posting
- Separate readable, partially_readable, unreadable and processing_error states
- Confirmed financial entries are locked and included in monthly reports and CSV exports
- PostgreSQL constraints and append-only audit/evidence history

## Getting started

Prerequisites: Ruby 3.2+, PostgreSQL 16+, libvips 42, Bundler.

1. Run bundle install.
2. Run bin/rails db:prepare.
3. Run bin/rails server.
4. Open http://localhost:3000/registration/new to create an account and private workspace.
5. Log in at /session/new to manage income and expenses.

Registration is enabled by default in development/test only. For production registration must be enabled explicitly with ENABLE_SIGNUP=true.

## Tests

Run bin/rails test and ruby tests/test_input_policy.rb. GitHub Actions also runs both against PostgreSQL.

## Security and evidence

Only authorized workspace users can view financial data or images. Original document versions, AI runs and audit events are retained. Additional evidence may be attached after confirmation without changing the confirmed financial snapshot. Human confirmation is required before entry into any financial report.

The system never parses image text using handcrafted OCR or amount/date heuristics. Unknown values remain blank or require manual entry.

## Implementation status

This repository contains a functional Rails foundation, not a production accounting release. A live llama.cpp/GGUF adapter is not enabled; the available research model did not pass the difficult-handwriting quality gate. Inventory/sales fulfillment, correction/reversal workflows, PDF exports, team membership and production hardening remain planned.


## Temporary Cloudflare Quick Tunnel preview

The development-only preview flag permits `*.trycloudflare.com` hostnames, suppresses detailed Rails debug errors, and disables public self-registration.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails server --binding 127.0.0.1 --port 3078
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:3078
```

Create a dedicated non-production preview account and use *synthetic* data only. Quick Tunnel URLs are temporary and not authentication. Production deployments must configure their own security and host policy. The GGUF inference adapter remains disabled in this preview.


## Dashboard, reports and language support

- Responsive finance workspace dashboard with four KPIs, transaction search, type/status filters and pagination.
- Expanded reports: previous-month comparisons, six-month trend, expense category shares, daily activity, recent confirmed entries and verified CSV export.
- English and Vietnamese interface switching with Rails I18n and a signed locale cookie. UI translations are stored in separate locale files; underlying financial data and CSV remain unchanged.
- Step-by-step in-app guide for manual input, evidence versioning, review and human confirmation.

**Details:** [Finance UX and reporting (English)](docs/UX_REPORTING.en.md).

The current Cloudflare preview remains limited to synthetic sample data; GGUF live inference is still disabled. The application does not claim production accounting compliance.
