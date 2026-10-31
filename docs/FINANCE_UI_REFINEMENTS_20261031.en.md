# Finance UI refinements — 2026-10-31

This update changes presentation and navigation only. It does not modify transactions, line items, documents, reporting totals, or the Tags-only schema.

- In the **Add an expense item** modal, the description field label is **Reason for expense** (Vietnamese: **Lý do chi**). Income items retain their existing label. The underlying `line_item.description` field and validation are unchanged.
- On a transaction detail page, **Review receipt and details** is a prominent action only if the draft was created through the upload-first receipt intake (identified by the recorded `receipt_first_draft_created` audit event) and still has an active receipt version. An existing manual draft with an attached document, such as synthetic transaction #6, instead prominently offers **Edit draft**. The saved document versions remain available in the Documents section. The dedicated receipt-first route and review requirement remain intact.
- The monthly dashboard KPI icons were exchanged: confirmed income is **↙** and confirmed expense is **↗**. No amounts or KPI calculations changed. Report page indicators were not modified.

Focused integration tests verify the modal label, manual-document vs receipt-first navigation, and both KPI icons. Previous acceptance tests for receipt-first upload continue to apply.
