# M7 — Quy trình điều chỉnh giao dịch có kiểm toán

## Nguyên tắc bảo toàn lịch sử

Giao dịch và các khoản chi tiết **đã xác nhận phải bất biến**, kể cả khi người dùng phát hiện sai ngày, số tiền hoặc danh sách mua hàng. Sửa trực tiếp sẽ làm mất khả năng đối chiếu bản gốc.

Chức năng điều chỉnh tạo **một giao dịch thay thế ở trạng thái nháp**, liên kết bằng bảng `finance_corrections`. Giao dịch gốc vẫn đã xác nhận và giữ nguyên số tiền, ngày, ảnh hóa đơn, dữ liệu AI và nhật ký kiểm toán.

## Cách sử dụng

1. Tại danh sách khoản chi của giao dịch đã xác nhận, chọn **Sửa chi tiết khoản** trên dòng cần chỉnh. Modal yêu cầu nhập lý do (10–2000 ký tự).
2. Khi lưu modal, hệ thống sao chép ngày, số tiền, loại giao dịch, mô tả, danh mục, giờ/địa điểm tùy chọn và **toàn bộ dòng chi tiết** sang bản nháp mới, chỉ áp dụng thay đổi vào bản sao của dòng được chọn. Ảnh hóa đơn tiếp tục gắn với bản gốc và bản thay thế có liên kết để xem lại.
3. Chỉnh sửa các dòng khác qua modal Turbo trên bản nháp; hỗ trợ cả hóa đơn 100 dòng.
4. Kiểm tra rồi chủ động xác nhận. Cả hai bản ghi vẫn được bảo toàn nhưng liên kết điều chỉnh xác định bản có hiệu lực.
5. Báo cáo, xu hướng tháng, phân bổ danh mục và CSV chỉ lấy **giao dịch đã chốt đang có hiệu lực**: bỏ giá trị gốc đã bị thay thế và tính giá trị mới đúng một lần.

Bản nháp điều chỉnh không thay đổi báo cáo. Chặn tạo hai correction cho cùng giao dịch gốc. Nếu bản thay thế sau này tiếp tục có sai sót, có thể tạo lần điều chỉnh khác trên chính bản thay thế, tạo thành chuỗi lịch sử. AI và tải ảnh không tự cho phép ghi nhận điều chỉnh.

## Cấu trúc kỹ thuật

- Bảng `finance_corrections` liên kết duy nhất giao dịch gốc, bản thay thế, workspace, người thao tác, lý do và trạng thái xác nhận.
- PostgreSQL có khóa ngoại, CHECK và trigger ngăn sửa/xóa correction đã chốt hoặc thay đổi nguồn gốc.
- Tạo và xác nhận correction đều chạy trong DB transaction với khóa dòng.
- Scope `effective_confirmed` loại bản gốc đã được thay thế khỏi thống kê.
- Audit append-only ghi nhận lúc yêu cầu correction và lúc bản thay thế có hiệu lực.

## Giới hạn

Đây là quy trình **thay thế phiên bản giao dịch**, chưa phải kế toán ghi sổ kép, bút toán đảo hay phát hành hóa đơn điều chỉnh đúng quy định pháp luật. Chưa có phân quyền duyệt nhiều vai trò, hủy correction đang nháp, báo cáo thuế hoặc nghiệm thu bảo mật production. Demo chỉ dùng dữ liệu giả lập.
