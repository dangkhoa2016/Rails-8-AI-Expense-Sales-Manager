# Fast receipt-item entry, live totals and reusable tags (M11)

## Primary experience

The **+ Add a single item** button opens a Turbo modal. Only the item description and a monetary calculation are front-and-center. Quantity defaults to **1**, while unit price stays blank until the user enters it. When both quantity and unit price are present, typing or changing either immediately computes the line total (**quantity × unit price**, rounded to two decimals). The line total becomes read-only while calculated. When unit price is missing, the amount is editable manually.

The browser calculation is a preview, not a financial authority. The Rails controller **independently computes the submitted quantity × unit price** for create/edit actions when both values are present, ignoring an inconsistent browser-supplied total. The manual CSV importer keeps its existing explicit `amount` semantics; the application does not reinterpret or guess prices from uploaded images. Successful draft-item creation, editing, deletion or import now synchronizes the draft transaction amount to the remaining line sum. The sync is audited and does not confirm a transaction. Users can still adjust draft totals for taxes or discounts before confirmation.

## Shared date and optional item time

The add/edit item modal displays the parent transaction's stored date. Items do **not** own a new date field or copy the current day. If the draft has no date, it is explicitly shown as unavailable until the transaction is edited; confirmation requires the parent date. Item time and location are optional, never prefilled with guessed values. Old `occurred_on` column values remain in historical records but are not used as the effective day.

## Multiple tags and create-on-save

Each item can carry multiple tags chosen as selectable chips in the same popup; a new tag can be created by typing its name under **Add new tags** (comma-separated names accepted). Up to 12 tags and six newly entered names are accepted per request. A newly created tag is scoped to the current workspace, unique by key, and the manually entered name initially appears identically in EN/VI. The owner can edit separate EN/VI translations in the existing **Tags** catalog at `/finance/tags`. No machine translation is claimed.

Tag assignment, tag creation, the saved item and the append-only audit event are atomic in PostgreSQL. A forged tag ID from another workspace is rejected. Database-level triggers prevent inserting, changing or deleting tag links attached to already-confirmed transactions. Correcting a confirmed item's tags creates a separate draft replacement and leaves the original data and tags intact. Existing single-category records are preserved; the migration attaches their matching catalog tags where possible, and older records retain a fallback label if no catalog tag exists.

The first selected tag also becomes the backward-compatible **primary category key** for the existing single-category reports. Secondary tags are labels only, not additional financial allocation: the same amount **must not be counted multiple times**. To implement multi-dimensional financial allocation in a later release requires a separate reporting model, not summing tag totals.

## Verification and limits

Rails integration tests cover shared parent date, optional time, client/server total consistency, new and existing tags, duplicate-name reuse, cross-workspace rejects, atomic rollback, DB immutability, and correction drafts. A standalone Node test verifies browser calculation and editable manual amounts. The CPU demo does not activate AI vision inference or fabricate unreadable receipt data.

The current multi-select tag UI is used in the item Add/Edit modal. The transaction-wide category field is retained for report compatibility; this change does not automatically transform every transaction-wide classification into a multi-tag allocation.


## Dialog interaction details

The Add/Edit item dialog does not close when its backdrop is clicked, or when Escape is pressed. Use the centered Close icon or the outlined Cancel action to abandon an unsubmitted edit. The successful Turbo Stream save still dismisses the modal and re-renders the affected item/summary. The Tags sidebar activation checkbox has its own correctly sized label/input layout.


## Responsive receipt-item list

On wide screens, the existing seven-column receipt item table remains available. On viewports narrower than 1,200px, **only this specific item table** rearranges into responsive, auto-fitting cards (two across where space permits, one across on phones). Every card clearly separates line number, item description and localized tags, amount, date/time/place, and its full **Edit / Delete** actions. A verified transaction date is required at confirmation; old item-date columns remain unchanged. Missing optional time and location are hidden in narrow cards.

The same semantic table rows and `id=finance_line_item_<id>` stay in the document so **Turbo Streams continue to replace the correct item** after a successful edit, and list-level replacement after create or delete continues to work. The table header remains in the accessibility tree. Pagination remains **25 items per page**, with unchanged links and a visually hidden semantic caption. This scoped CSS does not alter reports, catalog tables or CSV imports. Short English/Vietnamese date, time and place labels are shown inside cards. Responsive CSS is separate from the revised draft amount synchronization policy.

At 420px and narrower, item action buttons now occupy their own grid row after the optional time/place fields so a present item time remains visible instead of being covered.
