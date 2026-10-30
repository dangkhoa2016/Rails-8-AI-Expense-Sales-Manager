# Ngày chung của giao dịch, giờ và địa điểm tùy chọn theo khoản

> **Lưu ý cập nhật (30/10/2026):** Một số mô tả danh mục trong giai đoạn này là thiết kế lịch sử. Hiện hành chỉ dùng Tags; không còn cột danh mục đơn. Xem [đặc tả Tags-only](TAGS_ONLY_SCHEMA.vi.md).


Mỗi khoản chi tiết thuộc một `finance_transactions` và **lấy ngày có hiệu lực từ `transaction_date`**. Modal hiển thị ngày dùng chung nhưng không cho nhập ngày riêng. Nếu draft chưa có ngày, hệ thống không tự gán ngày hôm nay; người dùng phải kiểm tra ngày giao dịch trước khi chốt. Mỗi khoản vẫn có thể có `occurred_time` riêng (HH:MM) và `location_text` (tối đa 400 ký tự), đều tùy chọn. Không bắt buộc hoặc tự giả định các khoản phải khác giờ nhau.

Cột lịch sử `finance_line_items.occurred_on` được giữ lại **để truy vết**, nhưng form, nested attributes và CSV mới không ghi giá trị vào cột đó (NULL). Giao dịch confirmed cũ có thể chứa ngày riêng khác ngày cha; không backfill hoặc sửa dữ liệu gốc. Giao diện hiển thị ngày của transaction; bản nháp điều chỉnh giữ bản sao dữ liệu lịch sử phục vụ audit.

## Sửa khoản và tạo bản điều chỉnh

Mở `/finance/transactions/:transaction_id/line_items`, nhấn **Sửa chi tiết khoản**. Popup của draft cho phép sửa tên, tiền, số lượng, đơn giá, danh mục/Tags, giờ và địa điểm tùy chọn. Sau khi lưu, tổng tiền nháp đồng bộ có audit. **Để đổi ngày, sửa ngày ở transaction**, không sửa từng khoản.

Không ghi đè bản confirmed. Sửa dòng đã chốt yêu cầu lý do và tạo bản nháp điều chỉnh độc lập; giao dịch gốc bất biến. Báo cáo chỉ dùng bản thay thế sau khi người dùng xác nhận. Giao dịch chỉ có tối đa một bản điều chỉnh đang hoạt động; có thể hủy nháp chưa xác nhận bằng hành động ghi audit rồi tạo nháp khác.

## Nhập CSV

Cột bắt buộc: `description,amount`. Cột tùy chọn: `quantity,unit_price,category,occurred_time,location_text`. CSV cũ có cột `occurred_on` vẫn tương thích nếu mỗi ngày không rỗng hợp lệ và trùng ngày transaction; sai định dạng hoặc khác ngày phải rollback cả lượt nhập. Giờ/địa điểm không biết có thể để trống. Không tự viết OCR hoặc dùng heuristic đoán ngày/số tiền.

[CSV mẫu](../examples/receipt_lines_with_item_context.csv). Để tạo bản nháp ví dụ năm khoản có cùng ngày nhưng giờ/địa điểm khác nhau:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_individual_item_contexts.rb
```

Script chỉ chạy ở môi trường development, dùng dữ liệu giả lập, không sửa bản confirmed hoặc bản demo cũ đã có.
