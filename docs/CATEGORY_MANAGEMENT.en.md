# Tenant-owned bilingual categories (M8)

## Purpose and data compatibility

The application now has a Category Management page at `/finance/tags` with create, list, edit and delete/archive actions. Each category stores a **stable key** plus separately editable **English** and **Vietnamese** display names. Every category belongs to one workspace and cannot be accessed from another workspace.

The original `finance_transactions.category` and `finance_line_items.category` fields remain stable text keys, preserving confirmed immutable transactions and existing monthly reports/CSV data. Only the displayed label changes with the interface language. The selected category key is submitted from a dropdown when users create/edit a transaction or add/edit a receipt line. Legacy keys are automatically registered as workspace-owned catalog entries, without rewriting historical records. Unrecognized legacy keys have a neutral same-name fallback in both languages until a user supplies translations.

Keys must be ASCII lowercase alphanumeric with underscores, 2–50 characters and start with a letter. A key is immutable after creation; name_en/name_vi are required and editable. Keys are unique per workspace, not globally.

## Delete behavior

Deleting a **never-used** category removes its catalog row. When referenced by any transaction (draft or confirmed) or any line item within the workspace, Delete **archives** the category (`active=false`) instead. Archived categories disappear from new-entry dropdowns but retain their localized labels in old transaction details and reports. Users may reactivate an archived category through Edit. Re-running default/bootstrap initialization never restores archived or user-renamed categories.

Bootstrap inserts a small example catalog and discovers legacy keys already used in that workspace. It only inserts missing keys; it never overwrites user-supplied names, status, financial records or audit history. Example categories are reusable general business labels, not verified claims about any user transaction.

## UI improvements

The manual entry form places type, date, amount, category dropdown and description together; the M9 new-transaction page now prioritizes receipt upload and keeps this form as an optional fallback. Optional transaction-level time/place/details live in a closed disclosure section. Drafts are saved first; receipt items and evidence are then managed from the detail page via the existing item popup, which prevents a large embedded item editor from occupying the create form.

The transaction detail page prioritizes amount, status, category and item reconciliation. Receipt items are previewed up to five, with a prominent link to the full paginated manager. Evidence, optional context and audit history remain accessible in expandable sections; human confirmation and immutable correction workflow are preserved.

This enhancement does not add tax accounting or change any financial calculations.


## Multi-tag evolution

From M11, the catalog is presented as **Tags** in navigation and management, while the original `finance_categories` database table and `/finance/tags` endpoint remain for compatibility. Receipt **line items** may now select multiple tags or create new ones within their own add/edit modal. Existing transaction-level primary category reports still use one key. See [Fast item and multi-tag workflow](QUICK_ITEM_TAGS.en.md).


The legacy /finance/categories route remains available for bookmarks and existing clients; the database remains unchanged.

On screens up to 960px, the Tag catalog uses responsive labeled cards rather than a clipped five-column table; each card retains the key, Vietnamese and English names, status and Edit/Delete actions.
