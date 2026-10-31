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

## Responsive và đồng bộ trạng thái bộ lọc với server (31/10/2026)

Bộ lọc trang Báo cáo có bố cục grid responsive: trên desktop rộng, mẫu, hai trường ngày và nút thao tác được canh trên một hàng gọn; ở tablet, các nút xuống hàng riêng; ở điện thoại nhỏ, các thành phần xếp dọc và nút chiếm đủ chiều rộng. Dòng ghi chú kiểm toán luôn nằm ở hàng riêng bên dưới khoảng ngày đang áp dụng. Trang Lịch sử giữ bố cục responsive của nó, nhưng cùng dùng cơ chế bảo vệ trạng thái.

Preset và hai ngày trong URL là **khoảng ngày đã áp dụng** ở server. Trình duyệt có thể tự phục hồi nội dung form chưa gửi sau khi chuyển trang. Vì vậy, Stimulus đồng bộ lại ba điều khiển từ giá trị **server đã render** khi kết nối và khi khôi phục trang từ back/forward cache. Không tự động tính một preset khác lúc tải trang. Nếu người dùng chủ động đổi preset hoặc ngày nhưng chưa bấm **Áp dụng lọc**, form hiển thị thông báo **chưa áp dụng**, trong khi KPI, báo cáo và CSV vẫn tính theo khoảng server đã xác nhận.

Đã kiểm tra bằng Chromium có đăng nhập ở các viewport 375, 414, 768, 1024, 1366 và 1472px trên cả hai trang, bao gồm đồng nhất giá trị, tràn/đè CSS và thông báo chưa áp dụng. Không có migration, không sửa khoản tiền, và không thay đổi cách tính báo cáo.

## Lọc nhiều Tags (31/10/2026)

Cả **Lịch sử giao dịch** và **Báo cáo** đều có thể chọn **nhiều Tags** cùng với khoảng ngày. Mở mục **Lọc theo nhiều Tags**, tích các Tags cần xem (tối đa 50). Tags đã ngừng sử dụng vẫn xuất hiện để tra cứu giao dịch cũ. Nếu không tích Tag nào, hệ thống hiển thị cả giao dịch không có Tag.

Quy tắc tìm giao dịch là **BẤT KỲ (OR)**: khớp Tag gắn trực tiếp ở cấp giao dịch **hoặc** Tag trên bất kỳ khoản chi tiết nào. Tuy nhiên, **số tiền được lọc chính xác hơn**: nếu Tag được chọn gắn **trực tiếp vào giao dịch**, tính **toàn bộ số tiền gốc** đúng một lần. Nếu chỉ Tag của **khoản chi tiết** khớp thì **chỉ cộng tiền của các khoản chi tiết khớp**, mỗi khoản đúng một lần dù có nhiều Tags. Các khoản khác trong cùng hóa đơn không được cộng vào kết quả. Lịch sử vẫn hiển thị giao dịch để điều tra, kèm **số tiền khớp Tags** và **số tiền gốc**. Không sửa dữ liệu đã lưu.

Lịch sử kết hợp Tags với ngày, trạng thái, Thu/Chi, tìm kiếm và phân trang; KPI tiền và giá trị hiện trên các dòng dùng **số tiền khớp Tags**, đồng thời hiển thị thêm số tiền gốc bất biến. Báo cáo dùng số tiền khớp nhất quán cho tổng Thu/Chi/Chênh lệch, kỳ trước có cùng số ngày, phân bổ Tags đã chọn, biểu đồ ngày/tháng và danh sách giao dịch gần đây. Khi chọn Tags, phần phân bổ theo khoản chi tiết trùng thông tin được ẩn, tránh hai biểu đồ lặp nhau. Số bản nháp vẫn là chỉ tiêu vận hành của toàn workspace. CSV giữ cột **Amount** là tổng tiền gốc và thêm cột **MatchedTagAmount** để đối chiếu với KPI sau lọc; khi không lọc Tags, báo cáo và CSV giữ nguyên cách tính cũ.

Nút **Xem lịch sử trong khoảng ngày này** đã được chỉnh thành nút có nền, viền, icon và CSS responsive. Khi bấm, cả Tags và khoảng ngày đã chọn đều được giữ lại. Nút xuất CSV cũng giữ nguyên bộ lọc. Tag ID phải thuộc workspace đang đăng nhập; ID sai hoặc của tenant khác bị từ chối HTTP 400. Không có migration hay sửa dữ liệu tiền, chứng từ và lịch sử bất biến.
