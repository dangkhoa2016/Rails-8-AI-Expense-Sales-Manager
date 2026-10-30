# Hủy bản nháp điều chỉnh, khóa tổng tiền, Tags giao dịch và so sánh bản gốc

## Phạm vi và quy tắc tài chính

Giao dịch đã xác nhận là bản ghi tài chính **bất biến**. Điều chỉnh phải tạo bản nháp thay thế, giữ liên kết về nguồn và chỉ có hiệu lực báo cáo sau khi người dùng xác nhận. Ngày kế toán nằm ở transaction cha; mỗi `line_item` dùng chung ngày đó. Đợt này không triển khai heuristic đọc ảnh, parser OCR, suy đoán số tiền hoặc chạy GGUF inference mới.

## Hủy bản nháp điều chỉnh

Mở trang chi tiết **bản sao đang chờ điều chỉnh**, chọn **Hủy và bỏ bản nháp này**, nhập lý do từ 10–2.000 ký tự và xác nhận. Hệ thống chuyển cả correction và bản sao sang trạng thái **cancelled**, ghi audit append-only ở cả hai bản ghi và thêm một phiên bản lịch sử ở bản gốc với lý do, người hủy, thời gian và mã liên kết. **Bản confirmed gốc, chứng từ, số tiền và các dòng chi tiết gốc không thay đổi.** Bản sao bị hủy không còn xuất hiện trong danh sách đang làm việc, không thể sửa, xác nhận hoặc upload thêm, nhưng vẫn có thể mở bằng đường dẫn có xác thực để điều tra. Các PostgreSQL trigger ngăn sửa/xóa dữ liệu của bản đã hủy, gồm transaction, dòng chi tiết, context và liên kết Tags.

Đây là **xóa mềm có dấu vết**, không phải xóa vĩnh viễn dữ liệu kiểm toán. Sau khi hủy một bản sao đang chờ, người dùng có thể tạo correction mới cho bản gốc; lịch sử bản cũ vẫn lưu. Không cho hủy correction đã xác nhận. Tất cả thao tác đều giới hạn trong workspace có quyền truy cập.

## Tổng tiền chỉ tính từ các khoản chi tiết

Form sửa transaction và form kiểm tra chứng từ **không còn ô sửa tổng tiền**. Tổng tiền là trường chỉ đọc và thay đổi qua Thêm/Sửa/Import/Xóa các `line_item`. Số tiền người dùng nhập lúc tạo giao dịch thủ công được lưu thành **dòng chi tiết đầu tiên**, không phải tổng tiền tự do ở cha. Khi xóa dòng cuối cùng, tổng tiền nháp chuyển về 0. Giao dịch nháp do app mới tạo được đánh dấu `line_total_managed=true`; muốn xác nhận phải có ít nhất một dòng và tổng phải khớp chính xác tổng các dòng.

**Ngoại lệ cho dữ liệu lịch sử:** Giao dịch tạo ở phiên bản cũ có `line_total_managed=false` và giữ nguyên số tiền đã ghi, kể cả giao dịch không có dòng chi tiết. Không tự tạo dòng giả, backfill hay tính lại bản confirmed. Nếu correction của bản gốc lịch sử không có dòng thì giữ số tiền cũ cho đến khi người dùng tự tạo các khoản thực tế. Đây là ngoại lệ tương thích lịch sử, không phải cho phép AI hoặc ứng dụng suy ra số liệu.

Giá trị số tiền không được suy đoán từ ảnh. Con người luôn phải đối chiếu trước khi xác nhận.

## Chọn nhiều Tags ở transaction

Các form sửa và kiểm tra transaction dùng bộ chọn **nhiều Tags** tương tự popup `line_item`. Có thể chọn nhiều Tags sẵn có hoặc nhập các tên mới ngăn cách bằng dấu phẩy. Tên mới là do người dùng viết, không phải bản dịch máy. Tag được chọn đầu tiên vẫn là mã `category` phân loại chính nội bộ để báo cáo không cộng lặp; các Tags phụ không nhân đôi số tiền trong báo cáo. Giữ nguyên mã, tên EN/VI và dữ liệu đã dùng trước đây; Tag lưu trữ không thể gắn mới. Bảng liên kết riêng có ràng buộc duy nhất, validation kiểm tra workspace và trigger PostgreSQL để cấm thay đổi ngoài draft. Bản sao điều chỉnh kế thừa Tags; cập nhật Tags được ghi vào snapshot và lịch sử phiên bản.

## Đánh dấu bản sao và so sánh với bản gốc

Form sửa và trang chi tiết bản thay thế đều có cảnh báo **“Đây là bản sao của giao dịch đã xác nhận”**, liên kết mở bản gốc và khu vực so sánh bản gốc–bản thay thế. Danh sách khác biệt gồm ngày, tiền, mô tả, nhóm phân loại chính, Tags và các khoản chi tiết; với hóa đơn 100 dòng, chỉ các dòng có khác biệt được hiển thị trong phần mở rộng. So sánh cập nhật theo bản nháp hiện tại. Bản gốc luôn chỉ đọc; bản sao chưa làm thay đổi báo cáo cho tới lúc xác nhận riêng.

## Kiểm chứng và bằng chứng

Chạy migrations trên database test, regression tests và kiểm thử giao diện trước khi nâng cấp preview. Ưu tiên thử chặn khác workspace, bất biến bản đã hủy, tạo correction lại, khóa tổng tiền, xóa dòng cuối, chọn nhiều Tags và so sánh bản sao. Sao lưu database và lưu logs trước khi thay đổi. Preview hiện là dữ liệu giả lập; chưa bật GGUF vision inference và không tuyên bố đáp ứng chứng nhận kế toán production.
