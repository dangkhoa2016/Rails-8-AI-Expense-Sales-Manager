# Sorting receipt line items

The Itemized breakdown page (/finance/transactions/:id/line_items) now supports read-only sorting of the entire transaction's item list **before** pagination (25 items per page).

## Sort keys

| Key | Rules |
|---|---|
| Original order | Persisted position, ascending by default |
| Item name | Case-insensitive alphabetical |
| Amount | Numeric monetary value |
| Item time | Chronological; missing times always last |
| Location | Case-insensitive alphabetical; missing locations always last |

Every key supports ascending and descending order. Click a sortable heading on desktop to reverse the direction, with a sortable table heading on wide screens. The separate Sort by/Direction selector panel has been removed. The active table heading is annotated with accessible aria-sort and direction arrows. Original order is the default (and can be selected by clicking the # header).

The shared transaction date is not a sortable item attribute. Original receipt position labels remain unchanged (for example, #9 still identifies the original ninth item after sorting).

## Preservation and security

- Both the sort key and direction are validated against fixed allowlists. Unknown values produce HTTP 400, not arbitrary SQL.
- Equal values are ordered by persisted position then item ID, giving stable pagination. Null times/locations sort last in either direction.
- Sorting occurs before pagination. Changing a key starts at page one; paging links retain the selected sort and direction.
- Creating or editing draft items in a Turbo modal retains any sort query parameters; changes affecting the chosen key re-render the correct sorted list. An item created outside the current page has a link to its page under the selected sort.
- Deleting, importing CSV and non-Turbo redirects retain sorting. Confirmed transactions can be sorted but cannot be edited without the existing correction process.
- Sorting never changes stored position, financial amounts, Tags, date, receipt evidence or revision history. No migration or new AI service is required.

## Evidence

Integration tests cover ascending/descending, all sortable keys, missing values, cross-page ordering, invalid inputs, Turbo modal add/edit, deletion redirect and confirmed immutability. Authenticated Chromium verified transaction #14 (100 item rows) at 375, 414, 768, 1024, 1366 and 1472px, with responsive layout, numeric descending sort, name ascending sort and pagination state.

## Shared transaction date in the page header

The **Shared transaction date** now appears once, in a dedicated compact information strip directly under the page heading and above the item totals. Each item inherits this value from the parent transaction, so the repeated Date column was removed from the desktop table and responsive item cards. The item table now contains six columns: original row number, item name, amount, optional time, optional location and actions.

No individual item date is introduced or modified. Existing sorting, 25-row paging, Turbo modal editing and original receipt positions are unchanged.
