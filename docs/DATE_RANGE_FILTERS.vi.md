# Bộ lọc khoảng ngày: Lịch sử giao dịch và Báo cáo

Hai trang **Lịch sử giao dịch** (`/finance/transactions`) và **Báo cáo** (`/finance/reports`) cùng sử dụng bộ xử lý khoảng ngày. Dữ liệu được lọc theo **ngày giao dịch `transaction_date`**, không dựa trên ngày tạo bản ghi, tải chứng từ, chỉnh sửa, xác nhận hoặc giờ riêng của `line_item`. Lịch dùng múi giờ nghiệp vụ **Asia/Ho_Chi_Minh**; tuần bắt đầu **thứ Hai** và kết thúc Chủ nhật. `from=YYYY-MM-DD&to=YYYY-MM-DD` tính **cả ngày đầu và ngày cuối**.

## Mẫu chọn nhanh

| Mẫu | Khoảng ngày |
|---|---|
| Tuần này | Thứ Hai đến Chủ nhật của tuần hiện tại |
| Tuần trước | Thứ Hai đến Chủ nhật của tuần liền trước |
| 2 tuần đầu tháng này | Ngày 1–14 |
| 2 tuần cuối tháng này | Đúng 14 ngày cuối tháng, bao gồm ngày cuối (18–31/10/2026) |
| Tháng này | Từ ngày 1 tới ngày cuối tháng hiện tại |
| Tháng trước | Toàn bộ tháng liền trước |
| 7 ngày gần đây | Hôm nay và sáu ngày trước đó |
| 30 ngày gần đây | Hôm nay và 29 ngày trước đó |
| Tự chọn ngày | Hai ngày bắt đầu/kết thúc hợp lệ |
| Tất cả thời gian | Chỉ có trên trang Lịch sử giao dịch |

Chọn mẫu sẽ tự điền ngày vào hai trường; tự thay đổi ngày sẽ chuyển sang **Tự chọn ngày**. Rails luôn tính lại thời gian mẫu ở backend, không phụ thuộc dữ liệu do JavaScript gửi. Khoảng tùy chọn yêu cầu đủ hai ngày ISO, trong giai đoạn 1900–2100, ngày bắt đầu không sau ngày cuối. Báo cáo giới hạn khoảng dài xấp xỉ mười năm để tránh biểu đồ quá lớn. Tham số sai bị từ chối HTTP 400, không được đưa thẳng vào SQL.

## Cách hoạt động và tương thích

- Lịch sử giao dịch mặc định giữ **Tất cả thời gian**, bộ lọc nội dung, Thu/Chi, trạng thái, phân trang 20 dòng và cách ly workspace. Phân trang giữ nguyên khoảng ngày. Khi chọn khoảng cụ thể, KPI Thu/Chi/Chênh lệch ở đầu trang cũng tính theo khoảng đó; khi xem toàn bộ lịch sử mặc định, KPI vẫn là **tháng này**.
- Báo cáo mặc định là **tháng hiện tại**. Tổng tiền, số lượng, phân bổ Tags chính ở cấp giao dịch và khoản chi tiết, tổng theo ngày, giao dịch gần đây và **CSV xuất** cùng áp dụng một khoảng ngày, chỉ tính các giao dịch confirmed đang có hiệu lực. So sánh **kỳ trước** là khoảng liền trước có cùng số ngày với khoảng đang xem. Biểu đồ theo tháng hiển thị các tháng giao với khoảng đã chọn và hỗ trợ cuộn ngang nếu dài. Số bản nháp chờ duyệt vẫn là chỉ tiêu vận hành toàn workspace, không phải khoản tiền trong kỳ.
- URL cũ `/finance/reports?month=2026-10` và `/finance/reports/export?month=2026-10` vẫn tương thích. Tên file CSV bao gồm hai ngày đầu/cuối.
- Chuyển từ Lịch sử sang Báo cáo hoặc ngược lại sẽ giữ nguyên khoảng ngày. Quy tắc correction vẫn bảo đảm không tính đồng thời giao dịch gốc đã bị thay thế và bản corrected confirmed.

Không có migration, không chỉnh sửa dữ liệu tiền, lịch sử hoặc OCR. Các regression tests kiểm tra tháng/năm, năm nhuận, tham số sai, cách ly tenant, phân trang, CSV và logic chọn nhanh bằng JavaScript.
