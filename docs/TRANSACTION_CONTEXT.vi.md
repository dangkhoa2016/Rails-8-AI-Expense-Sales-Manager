# Thông tin chi tiết khoản thu chi — Tiếng Việt

**Ngày giao dịch vẫn bắt buộc khi xác nhận** một khoản thu hoặc chi. Giờ trong ngày và địa điểm là thông tin tùy chọn. Người dùng được lưu nháp khi chưa có ngày, đồng thời có thể nhập thủ công mà không cần ảnh hay AI.

## Các trường dữ liệu

- `finance_transactions.transaction_date`: ngày phát sinh khoản thu/chi do người dùng xác nhận.
- `finance_transaction_contexts.purchase_details`: mua, bán hoặc thanh toán cho việc gì; thông tin giải thích bổ sung có thể để trống.
- `finance_transaction_contexts.occurred_time`: giờ phát sinh tùy chọn, lưu dưới dạng giờ địa phương không kèm múi giờ (PostgreSQL `time without time zone`), hiển thị HH:MM. Không tự suy giờ từ EXIF hay lúc tải ảnh.
- `finance_transaction_contexts.location_text`: địa điểm dạng văn bản do người dùng nhập, tùy chọn, không phải địa chỉ đã xác minh bằng bản đồ/GPS.
- `finance_transaction_contexts.source`: `manual` hoặc `demo_seed`; form không được tự cung cấp provenance.
- `recorded_by_id`: tài khoản ghi nhận. Mỗi giao dịch có tối đa một bản ghi context liên kết bằng khóa ngoại duy nhất.

Thông tin được tạo/sửa trên giao dịch nháp. Khi đã chốt, Rails và PostgreSQL chặn sửa/xóa context. Giao dịch mẫu đã xác nhận trước đó được phép **bổ sung thông tin giải thích có nguồn gốc rõ ràng đúng một lần**, không sửa số tiền, ngày, trạng thái hoặc lịch sử kiểm toán đã có. Trigger PostgreSQL bảo vệ phần thông tin sau khi lưu.

## Ví dụ

Một khoản chi minh họa có thể ghi:

- Ngày: 26/04/2026
- Nội dung: Mua bánh mì ngọt ăn sáng
- Số tiền: 30.000 VND
- Giờ: 08:12 (**có thể bỏ trống**)
- Địa điểm: Tiệm bánh **giả lập** gần đồn cảnh sát tại Đà Nẵng (**có thể bỏ trống**)

Thông tin địa điểm chỉ để trình diễn tính năng, không xác nhận có cửa hàng thực tế hoặc giao dịch thật ở nơi đó.

## Seed dữ liệu demo

Sau khi có tài khoản demo trong môi trường development:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_reporting.rb
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/enrich_demo_transaction_contexts.rb
```

Script thứ hai đối chiếu 28 giao dịch mẫu theo ngày và số tiền, chỉ bổ sung ngữ cảnh một lần, đồng thời tạo giao dịch bánh mì mẫu có một dòng khoản chi trước khi xác nhận. Chạy lặp lại không tạo trùng; nếu nội dung đã tồn tại không khớp, script từ chối ghi đè. Script không chạy trên production và không tạo tài khoản.

CSV các giao dịch đã chốt có thêm ba cột mô tả, giờ và địa điểm (đều tùy chọn), với biện pháp tránh công thức bảng tính độc hại. Các số liệu báo cáo vẫn chỉ dựa trên số tiền và ngày giao dịch đã xác nhận, không suy từ ảnh hoặc thông tin bổ sung.
