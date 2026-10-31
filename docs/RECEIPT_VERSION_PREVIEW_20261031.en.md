# Receipt version previews — 2026-10-31

The transaction detail page previously listed evidence version links and SHA256 checksums but did not display image thumbnails. Because the section was collapsed by default, this could make a transaction with stored documents appear to have no images.

**Improvement:** when receipt versions exist, the Evidence/Receipt Versions disclosure opens by default and shows a responsive grid of thumbnails. Each thumbnail opens the matching version's dedicated document detail page, which continues to offer a link to the original protected image. The card includes the immutable version number, original file name, SHA256, and a label identifying the active version. Images use the existing authenticated, workspace-scoped image route; no new public file URLs are introduced. The underlying document, transaction, history and Active Storage records remain unchanged.

**Verified transaction #6:** two PNG blobs exist and their downloaded bytes match the database SHA256 values. They are synthetic UI test images explicitly labelled "SAMPLE DOCUMENT — NOT A REAL RECEIPT", not real receipts. The original files were preserved as-is; no image generation or OCR interpretation was applied.

Tests verify two thumbnail URLs, the default open state, protected image retrieval and SHA256 byte equality. Missing attachments are indicated rather than silently represented as working images. This does not alter human confirmation or GGUF inference policies.
