# Một trang tạo Thu/Chi và lịch sử phiên bản giao dịch có kiểm toán

## Một màn hình tạo giao dịch

Dùng **`/finance/transactions/new`** cho cả **Thu tiền** và **Chi tiền**. Giữ bố cục ưu tiên tải ảnh chứng từ và chỉ còn hai lựa chọn radio. Loại giao dịch được gửi đúng theo radio ở cả form upload và form nhập thủ công. Đổi lựa chọn **không tải trang hoặc làm mất dữ liệu đã nhập**. Link cũ `?kind=income` và `?kind=expense` vẫn mở cùng một trang, chỉ khác giá trị chọn ban đầu.

Upload ảnh tạo bản nháp chưa xác nhận, giữ ảnh gốc và SHA256, tuyệt đối không tự suy diễn số liệu hoặc chạy OCR tự viết. Nhập tay khoản chi có thể lưu nháp chưa đủ thông tin; nhập tay khoản thu vẫn yêu cầu backend xác minh số tiền, nguồn thu và ngày. Chọn **Thu tiền** sẽ tự mở phần thông tin bổ sung để thấy trường ngày bắt buộc.

## Hợp đồng sửa và lưu phiên bản

Giao dịch **draft** có thể sửa tại form thông thường hoặc màn hình kiểm tra chứng từ. Mỗi lần gửi form sửa phải có **lý do do người dùng nhập, dài 10–2.000 ký tự**. Khi dữ liệu thực sự thay đổi, hệ thống ghi một phiên bản mới đánh số, bất biến. Bản ghi lưu người thực hiện đã xác thực, workspace, thao tác, lý do, timestamp UTC, dữ liệu trước/sau và danh sách nhóm thay đổi. Giao diện hiển thị thời gian tới giây theo múi giờ Asia/Ho_Chi_Minh. Lưu lại mà không thay đổi giá trị không tạo phiên bản giả. `lock_version` trên form giúp chặn ghi đè một bản nháp bị sửa ở phiên khác.

Bảng `finance_transaction_revisions` mới có trigger PostgreSQL **không cho UPDATE/DELETE**. Việc cập nhật draft, tạo revision và ghi audit nằm trong một DB transaction. Audit cũ vẫn tồn tại; không gắn nhãn phiên bản mới cho các sự kiện cũ khi thiếu bằng chứng.

Snapshot gồm loại giao dịch, ngày, số tiền, nội dung, danh mục, ngữ cảnh tùy chọn và các khoản chi tiết kèm Tags đang có. Giao diện lịch sử liệt kê các nhóm thay đổi và cho mở xem giá trị trước/sau. Thao tác Thêm/Sửa/Xóa từng khoản và import CSV vẫn có audit riêng; **chỉ riêng thao tác từng khoản chưa tạo transaction revision mới** trong đợt này.

## Sửa giao dịch đã xác nhận

**Không sửa trực tiếp giao dịch confirmed.** Trang chi tiết cung cấp form nhập lý do để **Tạo bản nháp điều chỉnh**. Bản thay thế sao chép dữ liệu cha, các khoản chi tiết và ngữ cảnh. Giao dịch gốc vẫn bất biến, giữ ảnh/bằng chứng và thêm phiên bản ghi nhận yêu cầu điều chỉnh có liên kết sang bản thay thế. Khi sửa bản nháp thay thế, mỗi thay đổi có phiên bản mới. Sau bước xác nhận riêng do con người thực hiện, bản gốc có thêm phiên bản xác nhận thay thế, thể hiện trạng thái có hiệu lực. Báo cáo chỉ tính giao dịch confirmed đang có hiệu lực, không cộng trùng.

Mỗi bản gốc confirmed chỉ có tối đa một correction; các trigger bất biến PostgreSQL, tenant isolation và quy tắc xác nhận vẫn giữ nguyên. Không di chuyển hoặc ghi đè ảnh gốc.

## Kiểm chứng và giới hạn

Regression tests bao gồm giao diện chung, radio Thu/Chi, nhập tay/upload, lý do sửa, dữ liệu trước/sau, số phiên bản, không tạo phiên bản khi không đổi, chặn cập nhật stale, bất biến dữ liệu DB, kiểm tra khác workspace và quy trình correction. Sau deploy cần kiểm tra thực tế radio trên trình duyệt và responsive.

Demo CPU **chưa bật adapter AI GGUF**; không tuyên bố đã có OCR tự động hoặc đạt chứng nhận hệ thống kế toán production.


## Cập nhật tiếp theo về tổng tiền, Tags và hủy bản điều chỉnh

Sau khi hợp nhất form tạo Thu/Chi, hệ thống tiếp tục khóa tổng tiền transaction theo các khoản do người dùng nhập, bổ sung Tags nhiều lựa chọn ở cấp transaction và cho hủy mềm bản nháp điều chỉnh đang chờ với lịch sử kiểm toán. Xem [quy tắc hiện hành và ngoại lệ dữ liệu lịch sử](CORRECTION_DRAFT_TAGS_LINE_TOTAL.vi.md). Những mô tả trước đây về việc nhập tự do tổng tiền của bản nháp không còn áp dụng cho giao dịch mới tạo bởi app.
