# Rails 8 AI Expense & Sales Manager

Ứng dụng Rails 8 và PostgreSQL quản lý thu/chi, kiểm tra chứng từ bởi người dùng, lưu lịch sử ảnh và xuất báo cáo tài chính.

English: [README.md](README.md)

## Chức năng

- Đăng nhập theo cơ chế Rails 8, workspace riêng theo tài khoản.
- Nhập khoản thu/chi thủ công, không bắt buộc phải có ảnh hoặc kết quả AI.
- Ngày và số tiền giao dịch do người dùng xác nhận; không tự lấy từ EXIF hoặc thời điểm tải lên.
- Lưu mọi phiên bản ảnh chứng từ bằng Active Storage private, SHA256 và metadata.
- Lưu từng lượt AI nhận diện và từng trường gợi ý để kiểm tra độc lập, không tự động ghi tài chính.
- Phân biệt trạng thái đọc được, đọc một phần, không đọc được và lỗi xử lý.
- Chỉ tổng hợp giao dịch đã xác nhận vào biểu đồ tháng và CSV.
- PostgreSQL khóa giao dịch đã chốt và bảo toàn lịch sử audit/bằng chứng.

## Cài đặt và chạy

Yêu cầu Ruby 3.2+, PostgreSQL 16+, libvips 42 và Bundler.

1. Chạy bundle install.
2. Chạy bin/rails db:prepare.
3. Chạy bin/rails server.
4. Truy cập http://localhost:3000/registration/new để tạo tài khoản và workspace cá nhân.
5. Đăng nhập tại /session/new để quản lý thu/chi.

Mặc định tính năng đăng ký chỉ bật ở môi trường development/test. Trên production cần chủ động cấu hình ENABLE_SIGNUP=true.

## Kiểm thử

Chạy bin/rails test và ruby tests/test_input_policy.rb. GitHub Actions chạy lại cả hai bộ kiểm thử với PostgreSQL.

## Ngày từng khoản, Tags và tổng tiền nháp

Ngày chi/thu của line item bắt buộc phải được kiểm tra. Tổng tiền draft đồng bộ theo các dòng khi người dùng thêm/sửa/xóa/import; confirmed giữ nguyên. URL Tags: /finance/tags. Phần upload ảnh của khoản thu hiển thị sẵn.

Xem [quy tắc ngày và tổng nháp](docs/FINANCE_ITEM_DATE_TOTAL.vi.md).

## An toàn và bằng chứng

Người dùng chỉ được xem dữ liệu và ảnh thuộc workspace đã phân quyền. Mỗi ảnh là một phiên bản độc lập; kết quả AI và lịch sử audit được lưu giữ. Có thể thêm ảnh sau khi chốt mà không tự thay đổi giao dịch đã xác nhận.

Ứng dụng không tự suy ngày hoặc tiền bằng OCR regex, heuristic hoặc phép tính ngược từ ảnh. Trường không chắc chắn phải để trống, để người dùng nhập hoặc kiểm tra. Báo cáo chỉ tính dữ liệu được xác nhận.

## Trạng thái triển khai

Đây là nền tảng Rails có thể chạy, chưa phải phần mềm kế toán production. Chưa bật adapter llama.cpp/GGUF thực tế do model nghiên cứu chưa qua quality gate chữ viết tay khó đọc. Module tồn kho/bán hàng hoàn chỉnh, quy trình điều chỉnh giao dịch, xuất PDF, chia sẻ workspace theo vai trò và hardening production là các bước tiếp theo.


## Xem thử qua Cloudflare Quick Tunnel

Cờ chạy chỉ dành cho môi trường development sẽ cho phép hostname `*.trycloudflare.com`, tắt trang debug chi tiết của Rails khi truy cập từ tunnel và khóa chức năng tự đăng ký công khai.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails server --binding 127.0.0.1 --port 3078
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:3078
```

Chỉ sử dụng tài khoản demo riêng và dữ liệu tổng hợp giả lập. Link Quick Tunnel có thể đổi và không thay thế cơ chế xác thực. Triển khai production phải có bảo vệ host, phân quyền và hạ tầng riêng. Adapter GGUF inference chưa được bật trong bản demo này.


## Tổng quan, báo cáo và đa ngôn ngữ

- Dashboard tương thích máy tính và thiết bị di động, có bốn chỉ số tài chính, tìm kiếm, bộ lọc trạng thái/loại giao dịch và phân trang.
- Báo cáo có so sánh tháng trước, xu hướng sáu tháng, tỷ trọng danh mục chi, phát sinh theo ngày, danh sách giao dịch đã xác nhận và xuất CSV.
- Chuyển ngôn ngữ tiếng Anh / tiếng Việt bằng Rails I18n và signed cookie. Hai bộ dịch được lưu riêng; dữ liệu tài chính và CSV không đổi.
- Trang hướng dẫn từng bước về nhập thủ công, lưu phiên bản ảnh, kiểm duyệt AI và xác nhận giao dịch.

**Chi tiết:** [Giao diện và báo cáo thu chi (Tiếng Việt)](docs/UX_REPORTING.vi.md).

Bản demo Cloudflare hiện tại chỉ sử dụng dữ liệu giả lập. AI GGUF chưa được bật; ứng dụng chưa tuyên bố đạt chuẩn kế toán production.


## Dữ liệu demo nhiều tháng (tùy chọn)

Script chỉ chạy trong môi trường development, tạo các khoản thu/chi giả lập đã xác nhận cho giai đoạn tháng 5–10/2026 ở workspace demo được chỉ định. Có thể chạy lại mà không tạo trùng. Script không tạo tài khoản, không tạo ảnh hóa đơn và không sửa giao dịch đã tồn tại.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_reporting.rb
```

Script tự từ chối môi trường production và yêu cầu đúng tài khoản/workspace demo có sẵn. Chỉ chạy thủ công, không gọi từ seed mặc định. Mọi giá trị đều do chúng ta tạo để kiểm thử, không phải lịch sử tài chính thật.


## Chi tiết thu chi và địa điểm tùy chọn

Người dùng vẫn phải nhập **ngày phát sinh giao dịch** trước khi xác nhận. **Giờ trong ngày và địa điểm được phép để trống**; ứng dụng không tự suy từ EXIF, lúc tải ảnh hoặc kết quả OCR không chắc chắn. Mỗi bản nháp cũng có trường giải thích cụ thể mua hoặc thanh toán cho việc gì.

Phần mô tả bổ sung nằm trong bảng riêng, gắn với người tạo và nguồn dữ liệu. Khi còn nháp, có thể chỉnh sửa; sau khi đã chốt, PostgreSQL ngăn sửa/xóa. Việc thêm thông tin giải thích không làm đổi số tiền hoặc ngày thu/chi ban đầu.

Script seed tùy chọn cho môi trường development bổ sung thông tin vào các giao dịch **giả lập** đã xác nhận mà không viết lại sổ cái, đồng thời tạo ví dụ mua bánh mì ngọt **30.000 VND ngày 26/04/2026 lúc 08:12**. Một số mẫu cố tình để trống giờ/địa điểm để kiểm tra trường tùy chọn.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/enrich_demo_transaction_contexts.rb
```

Xem [tài liệu chi tiết khoản thu chi (Tiếng Việt)](docs/TRANSACTION_CONTEXT.vi.md). CSV có thêm cột nội dung chi tiết, giờ và địa điểm. Báo cáo vẫn chỉ dựa trên các khoản tiền đã xác nhận.


## Hóa đơn nhiều dòng và nhập hàng loạt (M6)

Một giao dịch có thể chứa tối đa **500 dòng khoản chi tiết**, mỗi dòng có tên, thành tiền, số lượng/đơn giá/Tags tùy chọn. Tổng tiền giao dịch vẫn phải **do người dùng xác nhận**; bản nháp đồng bộ số tiền từ tổng các dòng khi được thêm/sửa/xóa/import, nhưng tuyệt đối không suy từ OCR chưa được kiểm chứng.

Với bản nháp ngắn, dùng nút **Thêm dòng mới** trên form. Với hóa đơn dài, mở **Xem và quản lý tất cả khoản chi** để duyệt, sửa hoặc xóa theo trang (25 dòng/trang). Hoặc nhập CSV UTF-8 với hai cột bắt buộc `description,amount` và các cột tùy chọn `quantity,unit_price,tags,occurred_time,location_text`, tối đa 500 dòng/512 KiB. Hệ thống ghi nguyên tử, chống nhập trùng bằng SHA256 trong cùng giao dịch; CSV khác sẽ thêm mới, không tự thay dòng cũ.

Có thể tải [CSV ví dụ 100 dòng](examples/receipt_lines_100.csv), hoặc seed bốn hóa đơn **giả lập** 5/20/50/100 dòng trong tài khoản demo development đã tạo sẵn:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_itemized_receipts.rb
```

Báo cáo có thêm phân bổ theo Tag chính của các dòng đã chốt và chênh lệch đối chiếu, nhưng không cộng lại các dòng vào tổng thu/chi lần thứ hai. Đề xuất AI có thể được xem và duyệt từng dòng trên trang riêng; **OCR GGUF thực tế chưa được bật** vì còn phải nghiệm thu chất lượng model.

Xem [tài liệu M6 (Tiếng Việt)](docs/MULTI_LINE_RECEIPT.vi.md).


## Điều chỉnh giao dịch đã xác nhận (M7)

Khi phát hiện sai một dòng trong hóa đơn đã chốt, **không sửa giao dịch gốc**. Mở danh sách khoản chi rồi chọn **Sửa chi tiết khoản** trên dòng cần chỉnh. Modal yêu cầu lý do rồi tạo bản nháp thay thế. Ngày, số tiền, giờ/địa điểm tùy chọn và toàn bộ dòng chi tiết (kể cả hóa đơn 100 dòng) được sao chép để chỉnh sửa. Ảnh chứng từ gốc luôn nằm trong hồ sơ cũ, có liên kết để mở lại.

Khi người dùng xác nhận bản thay thế, báo cáo và CSV chỉ tính **giao dịch đã chốt đang có hiệu lực**, không cộng cả bản cũ và mới. Mỗi lần điều chỉnh có nguồn gốc và lịch sử kiểm toán bất biến. Bản nháp điều chỉnh không ảnh hưởng tổng thu/chi. Đây là cơ chế thay thế hồ sơ, chưa phải bút toán đảo chuẩn theo quy định kế toán.

Để xem ví dụ điều chỉnh hóa đơn 100 dòng trong development với dữ liệu hoàn toàn giả lập:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_correction.rb
```

Tài liệu: [Quy trình điều chỉnh (Tiếng Việt)](docs/CORRECTION_WORKFLOW.vi.md). M7 chạy bằng CPU; adapter AI GGUF vẫn chưa bật.


## Ngày chung của giao dịch, giờ và địa điểm tùy chọn theo khoản

Mọi khoản chi tiết **dùng ngày của transaction**, chỉ giờ (HH:MM) và địa điểm mới có thể nhập riêng, đều tùy chọn. Form khoản chỉ hiển thị ngày chung, không có ô sửa ngày hoặc tự điền giờ hiện tại. Giao dịch nháp được phép thiếu ngày trong lúc nhập khoản nhưng cần xác nhận ngày trước khi chốt. Cột ngày riêng cũ được giữ để audit, không tự backfill hoặc sửa hồ sơ confirmed.

Mở **danh sách khoản chi tiết** của bản nháp và nhấn **Sửa chi tiết khoản** ngay trên mỗi dòng để mở popup Turbo. Lưu thành công sẽ re-render đúng dòng vừa sửa cùng tổng đối chiếu, không refresh cả trang. Với khoản đã chốt, modal yêu cầu lý do rồi tạo bản nháp điều chỉnh có audit và chỉ cập nhật bản sao của dòng được chọn. Giao dịch gốc đã chốt không bị sửa. Nếu đã có correction thì trang dẫn đến bản thay thế. Ngày kế toán lấy trực tiếp từ transaction; số tiền nháp có dòng sẽ được đồng bộ sau khi thay đổi dòng, confirmed vẫn bất biến.

CSV mới chỉ cần `description,amount`, có thể thêm `occurred_time` (HH:MM), `location_text`; cột `occurred_on` của CSV cũ chỉ hợp lệ khi trùng ngày giao dịch — xem [CSV mẫu 5 dòng](examples/receipt_lines_with_item_context.csv). Để tạo 5 khoản chi **giả lập, có thể sửa được** trong bản nháp demo development:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_individual_item_contexts.rb
```

Tài liệu chi tiết: [Ngày giờ và địa điểm từng dòng (Tiếng Việt)](docs/ITEM_LEVEL_CONTEXT.vi.md).


### Popup thêm khoản chi và thanh công cụ gọn

Trong danh sách khoản chi của bản nháp, nút **+ Thêm một khoản chi** mở modal Turbo. Khi lưu thành công, hệ thống cập nhật bảng có phân trang và tổng đối chiếu, đóng popup, hiển thị thông báo mà không refresh toàn trang. Dữ liệu sai giữ form mở. Chức năng import CSV được thu vào mục mở rộng. Modal Sửa và nguyên tắc bất biến của giao dịch đã chốt không thay đổi. Xem [tài liệu hóa đơn nhiều dòng](docs/MULTI_LINE_RECEIPT.vi.md).


## Quản lý Tags song ngữ và giao diện giao dịch thống nhất

Menu **Tags** mở `/finance/tags`, cho phép quản lý nhãn riêng cho từng workspace với mã ổn định, tên tiếng Việt/tiếng Anh và trạng thái hoạt động/lưu trữ. Người dùng được gắn nhiều Tags cho transaction và từng `line_item`. Hệ thống **không còn bảng hoặc cột danh mục đơn**: dữ liệu lịch sử ở `finance_transactions.category` và `finance_line_items.category` được chuyển thành liên kết Tags có kiểm tra trước khi xóa cột; bảng danh mục cũ được đổi thành `finance_tags`. Báo cáo phân bổ theo **Tag đầu tiên** để mỗi số tiền chỉ được tính một lần, không nhân đôi vì nhiều nhãn.

Màn hình tạo Thu/Chi dùng chung một bố cục ưu tiên chứng từ, có radio Thu tiền/Chi tiền; nhập số tiền thủ công sẽ tạo khoản chi tiết đầu tiên và tổng tiền transaction luôn chỉ đọc. Xem [đặc tả di chuyển sang Tags](docs/TAGS_ONLY_SCHEMA.vi.md) và [quản lý Tags](docs/TAGS_MANAGEMENT.vi.md).

## Tải hóa đơn trước, kiểm tra rồi xác nhận (M9)

Luồng **Chi tiền** nay ưu tiên **Tải ảnh hóa đơn**: chọn Thu/Chi, chọn hoặc thả ảnh JPEG/PNG/WEBP (tối đa 10 MB), sau đó nhấn **Tải ảnh và tiếp tục**. Hệ thống tạo ngay **bản nháp chưa xác nhận**, lưu ảnh gốc và bằng chứng SHA256 rồi mở màn hình kiểm tra. Không cần nhập ngày, tổng tiền hoặc từng khoản trước khi upload. Mục nhập thủ công được thu gọn cho trường hợp không có ảnh.

Trang kiểm tra cho phép xem ảnh, nhập các trường đã xác minh và quản lý từng khoản bằng modal. **Adapter vision GGUF chưa được kết nối trong bản demo CPU**: upload không chạy inference hay tự chế số liệu. Đề xuất model đã lưu (nếu có) chỉ là gợi ý chưa xác nhận. Giao dịch luôn cần con người xác nhận riêng.

Xem [quy trình tải hóa đơn và giới hạn AI (Tiếng Việt)](docs/RECEIPT_FIRST_WORKFLOW.vi.md).


## Hai giao diện Chi tiền và Thu tiền (M10)

Trang tạo giao dịch có **một giao diện chung** tại `/finance/transactions/new`, dùng radio **Chi tiền** (`kind=expense`) và **Thu tiền** (`kind=income`) nhưng không tách bố cục. Cả hai cùng ưu tiên upload ảnh, có form nhập nhanh được thu gọn; nhập nhanh khoản thu yêu cầu số tiền của khoản đầu tiên, nguồn thu và ngày thực tế. Tổng tiền của transaction không được sửa tự do. Giao dịch hỗ trợ chọn nhiều Tags và đính kèm thêm chứng từ vào chính bản nháp hiện tại, không tạo giao dịch trùng.

Không yêu cầu các trường giờ, địa điểm và giải thích chung khi nhập mới. Ledger và dữ liệu lịch sử vẫn giữ nguyên; màn hình kiểm tra chỉ chỉnh sửa bản nháp và luôn cần xác nhận thủ công. Upload ảnh đã hoạt động nhưng **adapter inference GGUF chưa kết nối** trong demo CPU. Xem [tài liệu chuẩn hóa UI/UX thu chi (Tiếng Việt)](docs/FINANCE_DUAL_FLOW_UX.vi.md).


## Popup thêm khoản chi nhanh, tính tiền tự động và nhiều Tags (M11)

Popup khoản chi mặc định **số lượng 1** và hiển thị **ngày từ giao dịch đã lưu**, không tự điền ngày hoặc giờ hiện tại nếu chưa có. Ngày chỉ sửa ở transaction; giờ riêng trên từng khoản là tùy chọn, không phải kết quả AI đọc hóa đơn. Gõ số lượng hoặc đơn giá sẽ cập nhật thành tiền tức thì; Rails tính lại ở backend khi lưu. Nếu không có đơn giá vẫn có thể nhập thành tiền thủ công; tổng tiền giao dịch nháp có các dòng sẽ được đồng bộ từ các khoản sau khi lưu.

Mỗi khoản có thể **chọn nhiều Tags** dưới dạng chip hoặc nhập tên mới cách nhau bằng dấu phẩy ngay trong modal. Việc tạo tag và lưu khoản nằm trong cùng transaction, giới hạn workspace và được trigger PostgreSQL bảo vệ khi giao dịch đã chốt. Không còn cột danh mục đơn: báo cáo dùng Tag đầu tiên cho mỗi khoản để tránh cộng trùng; nhãn Tags có tên VI/EN riêng. Xem [quy trình thêm khoản nhanh và nhiều Tags](docs/QUICK_ITEM_TAGS.vi.md).


### Tinh chỉnh tương tác modal khoản chi (M11)

Popup Thêm/Sửa khoản chi có biểu tượng SVG đóng được căn giữa, nút **Hủy** kiểu viền rõ ràng và **chỉ đóng khi người dùng chủ động thao tác**. Click ngoài popup hoặc bấm Escape không làm mất nội dung đang nhập; bấm × hoặc Hủy để đóng. Khi lưu thành công, Turbo Stream vẫn đóng popup và cập nhật dòng khoản chi/tổng đối chiếu. Checkbox kích hoạt trong sidebar Quản lý Tags có CSS riêng, không bị kéo rộng như ô nhập văn bản.


### Thẻ khoản chi responsive cho màn hình nhỏ

Danh sách khoản chi giữ bảng bảy cột trên desktop rộng, nhưng tự chuyển thành các thẻ gọn dưới 1.200px: tên khoản, số tiền, Tags, ngày/giờ/địa điểm và nút Sửa/Xóa đều hiển thị đầy đủ, không phải cuộn ngang. Mỗi khoản vẫn giữ một ID để Turbo Stream cập nhật đúng dòng; phân trang giữ nguyên. Xem [tài liệu khoản chi và Tags](docs/QUICK_ITEM_TAGS.vi.md).

## Một trang tạo Thu/Chi và lịch sử phiên bản

Tạo cả **Thu tiền** và **Chi tiền** tại **`/finance/transactions/new`**, chọn một radio phía trên cùng giao diện tải ảnh chứng từ và nhập tay. URL cũ `?kind=` chỉ dùng để chọn radio mặc định, không còn hai layout khác nhau. Mỗi lần sửa bản nháp phải có lý do; những thay đổi được ghi thành phiên bản bất biến, đánh số, có dữ liệu trước/sau, thời gian và người sửa. Giao dịch confirmed không bị ghi đè: correction dùng bản nháp thay thế, giữ nguyên bản gốc, lưu lịch sử điều chỉnh và báo cáo chỉ tính bản confirmed đang có hiệu lực.

[Tài liệu một trang tạo Thu/Chi và phiên bản giao dịch](docs/UNIFIED_INTAKE_TRANSACTION_REVISIONS.vi.md).

## Hủy bản nháp điều chỉnh, khóa tổng tiền và chọn nhiều Tags

Có thể **hủy bản nháp điều chỉnh chưa xác nhận** khi nhập lý do; hệ thống xóa mềm bản sao khỏi danh sách đang làm việc nhưng giữ bản confirmed gốc và lịch sử. Tổng tiền nháp chỉ đọc và lấy từ các khoản do người dùng nhập; draft mới phải có ít nhất một dòng trước khi xác nhận, còn tổng tiền của dữ liệu lịch sử được bảo toàn. Transaction hỗ trợ chọn nhiều Tags tương tự các khoản chi tiết. Form bản sao luôn có cảnh báo và so sánh trực tiếp với bản gốc đã khóa. Xem [quy tắc và giới hạn chi tiết](docs/CORRECTION_DRAFT_TAGS_LINE_TOTAL.vi.md).

Màn hình bản nháp điều chỉnh có modal chỉ đọc để xem giao dịch gốc ngay tại chỗ, không mất nội dung chưa lưu. Nút hủy bản nháp có màu đỏ và form transaction không còn link Quản lý Tags dư thừa.

Thông báo giao dịch điều chỉnh phản ánh đúng ba trạng thái nháp/đã xác nhận/đã hủy; các nút xem giao dịch gốc và “Đóng chi tiết” có CSS trung tính, căn giữa và responsive.

Các khoản chi tiết khác giao dịch gốc hiện mở trong modal chỉ đọc; đã bỏ tiêu đề tổng hợp so sánh bị lặp, vẫn giữ những trường trước/sau thực sự thay đổi.

Cải tiến UI ngày 31/10/2026: modal thêm khoản chi dùng nhãn **Lý do chi**, chỉ bản nháp tạo bằng quy trình tải hóa đơn trước hiển thị nút kiểm tra chứng từ ở đầu trang, và hai mũi tên KPI thu/chi được hoán đổi. [Chi tiết](docs/FINANCE_UI_REFINEMENTS_20261031.vi.md).

Cải tiến chứng từ (31/10/2026): trang chi tiết transaction hiển thị ảnh thu nhỏ của các phiên bản chứng từ, kèm SHA256 và đường dẫn xem ảnh có kiểm tra quyền. [Chi tiết](docs/RECEIPT_VERSION_PREVIEW_20261031.vi.md).

Bộ lọc khoảng ngày (31/10/2026): Lịch sử giao dịch và Báo cáo dùng chung Từ ngày–Đến ngày, các mẫu tuần/2 tuần đầu-cuối tháng/tháng trước, đồng bộ KPI, báo cáo và CSV. [Hướng dẫn tiếng Việt](docs/DATE_RANGE_FILTERS.vi.md).
