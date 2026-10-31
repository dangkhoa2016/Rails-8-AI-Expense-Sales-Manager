# Điều chỉnh giao diện tài chính — 31/10/2026

Lần cập nhật này chỉ thay đổi nhãn và điều hướng giao diện. Không sửa giao dịch, khoản chi tiết, chứng từ, tổng tiền báo cáo hoặc cấu trúc Tags-only.

- Trong modal **Thêm một khoản chi**, nhãn trường nội dung được đổi từ **Tên khoản** thành **Lý do chi**. Modal của khoản thu giữ nguyên nhãn trước đây. Cột lưu dữ liệu vẫn là `line_item.description`, không thay đổi validation.
- Ở trang chi tiết giao dịch, nút **Kiểm tra hóa đơn và thông tin** chỉ được ưu tiên khi bản nháp thực sự xuất phát từ quy trình **tải hóa đơn trước**, có audit event `receipt_first_draft_created` và phiên bản ảnh đang hoạt động. Bản nháp thủ công có ảnh đính kèm, như giao dịch demo #6, sẽ ưu tiên **Sửa bản nháp**; các phiên bản ảnh vẫn nằm trong mục **Chứng từ**. Chức năng kiểm tra hóa đơn của quy trình receipt-first vẫn được giữ.
- Đã hoán đổi biểu tượng KPI tại trang tổng quan tháng: **Tổng thu đã xác nhận** dùng **↙**, **Tổng chi đã xác nhận** dùng **↗**. Không đổi phép tính hoặc số liệu. Các biểu tượng ở trang báo cáo không nằm trong phạm vi thay đổi này.

Các integration tests kiểm tra nhãn modal, điều hướng của bản nháp thủ công và receipt-first, và cả hai biểu tượng KPI. Những bài test quy trình tải hóa đơn trước được giữ nguyên.
