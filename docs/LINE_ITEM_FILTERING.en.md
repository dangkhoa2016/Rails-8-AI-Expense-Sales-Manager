# Filtering receipt line items

The itemized transaction page at `/finance/transactions/:id/line_items` provides **read-only filters** for the current transaction. The filters are not transaction-wide search criteria and do not modify any ledger values.

## Available filters

- **Item name contains**: substring search, case-insensitive. Special SQL wildcard characters are treated as literal text.
- **Time from / Time to**: optional 24-hour `HH:MM` boundaries, inclusive, using each item's `occurred_time` (not the shared `transaction_date`). An item with no time is excluded if either time filter is set.
- **Minimum / Maximum amount**: optional inclusive bounds for the item's own `amount`. Enter plain numeric amounts, without thousands separators; values with up to two decimal places are accepted. No inferred monetary values are added.
- **Multiple Tags**: select any number of workspace Tags (maximum 50, archived Tags included). Items matching **any selected Tag (OR)** are returned once, even if the item has multiple selected Tags. Transaction-level Tags do **not** qualify other items; only their own item-Tag relations count.

Different filter groups are combined with **AND**; the selected Tags are combined with **OR** within their group. Each range accepts just a lower or just an upper bound. If both boundaries are supplied, the lower must be less than or equal to the upper. Invalid types, malformed times/amounts or reversed ranges return HTTP 400. In particular, time ranges do **not** wrap around midnight; cross-midnight items must be searched in separate ranges.

The list shows a separately labeled **matching item count and matching item sum**. These are only a view into the current transaction's item rows. The full transaction reconciliation summary and confirmed money remain untouched.

## Interaction and safety

Filtering happens in PostgreSQL **after** parent transaction/workspace authorization, **before** allowlisted sorting and 25-row pagination. The extra `line-item-sort-controls` selector panel has been removed. Existing sortable table headings remain clickable on wide screens; their links and pagination preserve selected Tags and other filters. Changing filters resets to page one; Clear filters preserves the current sort. Default ordering remains original receipt position.

New/edit Turbo dialogs, draft-only import, delete and subsequent redirects carry the active filters, including each selected `tag_ids[]` value. Turbo additions/edits refresh the filtered list, including when a changed item moves out of the result set. If a new item is outside the active filters, the confirmation provides a link to that item in the unfiltered list rather than suggesting it can be found in the filtered results. Confirmed transactions remain read-only unless the existing correction workflow is used.

The original six-column table, shared parent transaction date, original item positions, Tags and all historical evidence are unchanged. No schema migration, OCR or GGUF inference is required.

## Validation

Integration tests cover multi-Tag OR semantics, duplicated selected Tags, archived/foreign-workspace Tags, malformed arrays, combined filters, preserved URL/form state, Turbo edits, name literal matching, inclusive time/amount, combined filters, optional missing time, stable sorting and pagination, empty results, invalid query values, Turbo forms and workspace access. This document describes filtering behavior only; no production or accounting acceptance is implied.

## Compact filter layout and direct result navigation

The filter panel is now a native, keyboard-accessible `details/summary` disclosure. It is **collapsed by default**, including after a filter is applied; the summary displays the count of active criteria. The Clear filters action remains visible next to the disclosure whenever a filter is active. The matched-item count and sum appear immediately above the table, not in a separate full-width notification.

Submitting the filter uses a normal GET navigation (not Turbo interception) to preserve the browser fragment, landing at `#line_item_results` on the refreshed page, so the matching rows (or the empty-state message) are immediately in view without manually scrolling past the transaction header and reconciliation summary. Pagination and desktop column-heading sorting use the same results anchor. The original filtering semantics, 25-item pages, parent transaction totals and authorization checks do not change.
