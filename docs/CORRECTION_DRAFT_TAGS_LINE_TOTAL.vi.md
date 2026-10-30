# Hủy bản nháp điều chỉnh, khóa tổng tiền, Tags giao dịch và so sánh bản gốc

> **Lưu ý cập nhật (30/10/2026):** Một số mô tả danh mục trong giai đoạn này là thiết kế lịch sử. Hiện hành chỉ dùng Tags; không còn cột danh mục đơn. Xem [đặc tả Tags-only](TAGS_ONLY_SCHEMA.vi.md).


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

Form sửa và trang chi tiết bản thay thế đều có cảnh báo **“Đây là bản sao của giao dịch đã xác nhận”**, liên kết mở bản gốc và khu vực so sánh bản gốc–bản thay thế. Danh sách khác biệt gồm ngày, tiền, mô tả, nhóm phân loại chính, Tags và các khoản chi tiết; với hóa đơn 100 dòng, chỉ các dòng có khác biệt được hiển thị trong modal khi bấm nút số khoản thay đổi. So sánh cập nhật theo bản nháp hiện tại. Bản gốc luôn chỉ đọc; bản sao chưa làm thay đổi báo cáo cho tới lúc xác nhận riêng.

## Kiểm chứng và bằng chứng

Chạy migrations trên database test, regression tests và kiểm thử giao diện trước khi nâng cấp preview. Ưu tiên thử chặn khác workspace, bất biến bản đã hủy, tạo correction lại, khóa tổng tiền, xóa dòng cuối, chọn nhiều Tags và so sánh bản sao. Sao lưu database và lưu logs trước khi thay đổi. Preview hiện là dữ liệu giả lập; chưa bật GGUF vision inference và không tuyên bố đáp ứng chứng nhận kế toán production.

## Modal xem giao dịch gốc (cải tiến giao diện)

Trong màn hình **Sửa** và **Chi tiết** của bản nháp điều chỉnh, hai nút **Xem giao dịch gốc đã khóa** và **Giao dịch gốc (bất biến)** cùng mở **một modal chỉ đọc** mà không điều hướng sang trang khác. Modal hiển thị trạng thái đã xác nhận, số tiền, ngày, loại giao dịch, nội dung, Tags theo ngôn ngữ, ngữ cảnh, **toàn bộ các khoản chi tiết**, chứng từ và lý do của các phiên bản lịch sử của bản gốc. Liên kết chứng từ mở **tab riêng** để bản nháp đang nhập không bị thay đổi. Đóng modal bằng nút X hoặc **Đóng chi tiết**; không tự đóng khi bấm bên ngoài hoặc nhấn Escape. Sau khi đóng, focus quay lại nút đã mở modal. Giao diện tương thích màn hình nhỏ.

Nút **Hủy và bỏ bản nháp này** có màu **đỏ** rõ ràng để phân biệt thao tác phá hủy trạng thái, nhưng vẫn yêu cầu nhập lý do và xác nhận. Form transaction tiếp tục cho chọn/tạo nhiều Tags, chỉ bỏ liên kết **Quản lý Tags** không cần thiết ngay trong form; menu Tags toàn ứng dụng giữ nguyên. Các thay đổi giao diện không tự cập nhật tài chính, không đổi trạng thái correction và không nới quyền workspace.

## Thông báo theo trạng thái thực tế và CSS nút modal

Khối so sánh giao dịch điều chỉnh hiện xác định tiêu đề, nhãn trạng thái và mô tả theo **trạng thái thực của transaction thay thế**, không mặc định mọi bản thay thế đều là nháp. Nếu còn `draft`, giao diện ghi rõ đó là bản sao đang sửa. Nếu `confirmed`, hiển thị **“Giao dịch điều chỉnh đã xác nhận”**, giải thích rằng giao dịch thay thế đã có hiệu lực trong báo cáo, còn giao dịch gốc luôn được lưu để kiểm toán. Nếu `cancelled`, hiển thị cảnh báo bản đã hủy/lưu trữ riêng. Cả giao dịch gốc và bản thay thế đã xác nhận đều không cho sửa trực tiếp.

Hai nút xem giao dịch gốc và nút **“Đóng chi tiết”** trong modal được sửa CSS riêng: nền trắng, chữ xanh đậm, căn giữa, vùng nhấn tối thiểu 44px, hover/focus rõ ràng và responsive trên điện thoại. Không phụ thuộc kiểu button xanh toàn cục. Đóng modal không đổi URL hoặc làm mất nội dung form hiện tại.

Đây chỉ là thay đổi UI/ngôn ngữ: không tạo migration, không sửa transaction, correction, lịch sử, và không thêm OCR/AI inference.


## Modal riêng cho các khoản chi tiết khác bản gốc

Trong trang sửa hoặc chi tiết giao dịch điều chỉnh, dòng **“N khoản chi tiết khác bản gốc”** là một nút mở modal riêng. Modal hiển thị **chỉ những line items khác biệt**, có đối chiếu giá trị ở bản gốc và bản thay thế, làm nổi bật trường đã sửa; dữ liệu chỉ đọc. Người dùng có thể đóng chủ động bằng nút X hoặc **Đóng chi tiết**; Escape không đóng ngoài ý muốn. Khi đóng, trang hiện tại và các thay đổi chưa lưu ở form vẫn được giữ nguyên.

Đã **bỏ tiêu đề tổng hợp “So sánh với giao dịch gốc · N thay đổi”** ở đầu trang nhằm tránh lặp với sidebar. Những khác biệt về số tiền, nội dung, Tags… vẫn được trình bày ngắn gọn ngay dưới tóm tắt bản gốc và bản thay thế. Modal phù hợp màn hình nhỏ và có vùng cuộn độc lập; không có thao tác cập nhật dữ liệu tài chính.
