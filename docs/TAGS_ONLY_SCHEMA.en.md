# Tags-only finance schema — migration contract and behavior

## Why the previous category was removed

The former single-string `category` on transactions and line items duplicated the many-to-many Tags already selected by users. Keeping both created inconsistent reports, redundant editor fields and mismatched historical labels.

**Current storage:** `finance_tags` (stable key, localized `name_en` and `name_vi`, workspace, active status); `finance_transaction_tags(transaction_id, tag_id)`; `finance_line_item_tags(line_item_id, tag_id)`. The `category` columns on `finance_transactions` and `finance_line_items` are absent. The former `finance_categories` table has been renamed, not erased. Runtime model is `Finance::Tag`, not `Finance::Category`.

## Data preservation and safety

Migration `20261030200500_replace_legacy_categories_with_tags.rb` is **irreversible** by design; make a private PostgreSQL dump first. It inserts any missing legacy tag names (with stable safe keys) without overwriting existing tenant-edited Tag translations. Before dropping obsolete columns, it attaches missing Tags for categorized transactions and items — including confirmed historical records — as metadata links. Only the Tag-association mutability triggers are temporarily disabled within the migration transaction to allow this insert-only historical backfill; ledger values, financial status, dates, attachments, line items, revision JSON and audit logs are **not updated**. The migration verifies no categorized row is left without a tag before removing columns and restores trigger enforcement. Existing multi-Tag associations are retained without flattening.

Important: this migration does **not** rewrite historical revision or audit JSON, whose original data is evidence. Legacy schema migrations in the Git history are likewise preserved for reproducible fresh installation.

## Reports and exports

Transaction-level and item-level spending reports allocate each amount to the **first associated Tag (smallest link ID)**. Other Tags are descriptive filters and do not multiply revenue or spending; if no Tag exists, the amount is grouped as untagged. The effective-confirmed correction rule remains, so original and replacement are not summed twice. The CSV export field is **Tags** (semicolon-separated keys), not Category. Item import accepts required `description,amount` and optional `quantity,unit_price,tags,occurred_time,location_text`; Tags are comma/semicolon-separated existing workspace keys. Unknown or cross-tenant keys cause an atomic rejection rather than creating guessed classifications. Historical `occurred_on` CSV dates remain accepted only for parent-day equality.

## Rollout checklist

- Dump development data privately; record SHA256 and live row/ledger counts.
- Restore the dump to an isolated database and apply the migration there first. Compare all financial amounts, counts, confirmed statuses, correction links and append-only evidence before and after.
- Validate Tag relationships for existing categorized rows, confirmed mutation triggers and report totals (single-count allocation).
- Run Rails/Node integration checks and authenticated browser verification on the clone.
- Only after these gates pass, migrate the preview DB and check its original records and reports.
- No GGUF inference or image-specific OCR workaround is involved.

The demo uses synthetic finance data. This is a database schema transition, not an accounting certification or external financial data import.
