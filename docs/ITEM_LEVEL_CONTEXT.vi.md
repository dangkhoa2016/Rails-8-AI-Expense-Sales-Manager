# Ngày, giờ và địa điểm riêng trên từng khoản chi tiết

Mỗi dòng `finance_line_items` có **ba trường tùy chọn riêng**: `occurred_on` (ngày YYYY-MM-DD), `occurred_time` (giờ địa phương HH:MM, 24 giờ) và `location_text` (địa điểm dạng văn bản, tối đa 400 ký tự). Ngoài ra có tên hàng, thành tiền, danh mục, số lượng/đơn giá tùy chọn. Ba trường này đều cho phép `NULL`. **Không** tự chép ngày của transaction, lấy thông tin EXIF hay sao chép dữ liệu của dòng khác. Giờ không đồng nghĩa đã biết múi giờ. Ngày giao dịch kế toán vẫn là trường riêng, bắt buộc khi chốt.

Ví dụ dòng giả lập: "Mua bánh mì ngọt – 30.000 VND – ngày 26/04/2026 – 08:12 – tại tiệm bánh mẫu gần đồn cảnh sát Đà Nẵng". Các dòng khác trong cùng transaction có thể có ngày/giờ/địa điểm khác nhau hoặc để trống hoàn toàn. Tên và địa điểm ví dụ không xác nhận sự tồn tại của cửa hàng thực tế.

## Cách chỉnh sửa từng dòng

- **Bản nháp**: mở `/finance/transactions/:transaction_id/line_items`, chọn **Sửa chi tiết khoản** ngay trên dòng. Modal popup Turbo/Stimulus có tên hàng, giá tiền, số lượng, đơn giá, danh mục, ngày, giờ và địa điểm. Để trống thì lưu `NULL`. Mọi thay đổi được audit; sửa một dòng **không** tự đổi tổng tiền của transaction.
- **Đã xác nhận**: bản gốc không thể sửa. Nhấn **Sửa chi tiết khoản**, nhập lý do ngay trong modal rồi lưu. Hệ thống tạo bản nháp điều chỉnh có đủ các dòng, chỉ sửa **bản sao của dòng được chọn** và re-render dòng gốc thành liên kết đến bản nháp mới. Bản gốc giữ nguyên ảnh và lịch sử; chỉ sau khi xác nhận bản mới thì báo cáo mới chuyển sang giá trị thay thế.
- **Đã có bản điều chỉnh**: liên kết đến giao dịch thay thế, tránh tạo correction trùng. Turbo Streams cập nhật đúng dòng và phần tổng đối chiếu, đóng popup khi thành công hoặc giữ popup và hiển thị lỗi. Không còn trang GET correction/new.

## Import thủ công bằng CSV

Vẫn bắt buộc `description`, `amount`. Các cột tùy chọn có thể thêm: `quantity`, `unit_price`, `category`, `occurred_on`, `occurred_time`, `location_text`. Ngày theo `YYYY-MM-DD`, giờ theo `HH:MM` 24 giờ; không biết thì để trống. Dữ liệu lỗi làm rollback toàn bộ lượt import. Không có OCR tự viết hoặc heuristic đọc ảnh theo từng mẫu.

Xem [CSV mẫu](../examples/receipt_lines_with_item_context.csv). Có thể tạo **bản nháp demo 5 khoản chi** với ngày/giờ/địa điểm khác nhau:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_individual_item_contexts.rb
```

Đây là dữ liệu hoàn toàn giả lập; một số dòng chủ động thiếu thông tin để kiểm tra trường tùy chọn.
