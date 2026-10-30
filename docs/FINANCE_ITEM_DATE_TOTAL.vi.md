# Ngày chung theo giao dịch và đồng bộ tổng tiền có audit

## Một ngày giao dịch

`finance_transactions.transaction_date` là **ngày duy nhất** của một giao dịch. Mọi khoản chi tiết hiển thị ngày này; modal Thêm/Sửa khoản không có trường ngày độc lập. Bản nháp được phép chưa có ngày khi đang nhập dữ liệu, nhưng phải bổ sung ngày giao dịch trước khi xác nhận. `occurred_time` (HH:MM) và `location_text` vẫn có thể đặt riêng cho từng khoản, đều tùy chọn; hệ thống không đoán hoặc tự điền giờ hiện tại.

Khoản mới không ghi giá trị vào cột lịch sử `finance_line_items.occurred_on` (NULL). Không tự sửa dữ liệu cũ, kể cả ngày từng khoản khác ngày giao dịch. Hồ sơ confirmed gốc và nguồn gốc bản điều chỉnh được giữ nguyên. **Ngày có hiệu lực để hiển thị và báo cáo lấy từ transaction**, không phải cột ngày cũ. Sửa ngày transaction nháp sẽ thay đổi ngày hiển thị của tất cả khoản.

## Nhập tay và CSV

CSV mới chỉ cần `description,amount`; có thể thêm `quantity,unit_price,category,occurred_time,location_text`. CSV cũ có `occurred_on` vẫn được nhận để tương thích nhưng nếu có ngày thì phải là ISO hợp lệ và **trùng ngày giao dịch**. Nếu khác, import bị từ chối và rollback toàn bộ, không âm thầm bỏ qua ngày mâu thuẫn. Khoản nhập không lưu ngày riêng. Cơ chế SHA256 chống nhập lặp giữ nguyên. Không đọc hay đoán ngày bằng OCR tự viết.

## Tổng tiền và dữ liệu đã chốt

Tạo, sửa, xóa hoặc import khoản trong draft đồng bộ tổng giao dịch theo tổng các khoản, **kể cả 0 khi xóa khoản cuối**; thay đổi được audit trong cùng DB transaction. Giao dịch mới do app tạo cần có ít nhất một khoản để xác nhận và tổng phải khớp các dòng. Giao dịch lịch sử chưa có dòng giữ giá trị cũ, không backfill bằng dữ liệu đoán. Không tự sửa giao dịch confirmed, ngày lịch sử hoặc đề xuất AI. Xem [quy tắc khóa tổng và hủy bản nháp điều chỉnh](CORRECTION_DRAFT_TAGS_LINE_TOTAL.vi.md).

## Tags và chứng từ khoản thu

Trang quản lý chính là `/finance/tags`; `/finance/categories` vẫn được hỗ trợ. Tag trùng mã `key` hiển thị thông báo validation có bản dịch EN/VI, không còn chuỗi “Translation missing”. Upload ảnh chứng từ khoản thu vẫn có sẵn; không tự bật inference GGUF.

## Phạm vi kiểm chứng

Regression tests bao gồm ngày chung, giờ tùy chọn, CSV cũ, rollback nguyên tử, thông báo Tag, audit và bất biến confirmed. Chưa nghiệm thu thực tế inference GGUF hoặc kiểm thử hình ảnh trình duyệt responsive thủ công.
