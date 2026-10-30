# Workspace Tags — English

Open `/finance/tags` to create, edit, archive and reactivate localized Tags. Each Tag has a stable code (`key`) and independent EN/VI names. Many Tags may be assigned to a transaction or an item. The old single-category dropdown, the `category` database columns and legacy `/finance/categories` endpoint are no longer part of the application.

Tag keys cannot be mutated after creation. Tag labels may be edited and automatically appear in historic records. Deleting a referenced Tag archives it rather than destroying its association or audit context. An unused Tag can be deleted. Archived Tags remain visible on old transactions but cannot be newly attached. Workspace membership is enforced in Rails validation and database triggers.

See [Tags-only finance schema, reporting and migration](TAGS_ONLY_SCHEMA.en.md).
