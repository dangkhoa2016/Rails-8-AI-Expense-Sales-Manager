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
