# Lọc danh sách khoản chi tiết

Trang `/finance/transactions/:id/line_items` có bộ lọc **chỉ phục vụ tra cứu** các khoản thuộc giao dịch hiện tại. Đây không phải chức năng tìm kiếm giao dịch toàn hệ thống và không sửa số tiền đã ghi nhận.

## Các điều kiện lọc

- **Tên khoản chứa**: tìm chuỗi con, không phân biệt chữ hoa/chữ thường; ký tự đặc biệt của SQL được hiểu là văn bản bình thường.
- **Giờ từ / Giờ đến**: có thể bỏ trống một hoặc cả hai đầu, định dạng `HH:MM` 24 giờ; so sánh bao gồm hai đầu trên `occurred_time` của từng khoản, không phải `transaction_date` dùng chung. Khoản chưa có giờ không khớp khi chọn ít nhất một mốc giờ.
- **Số tiền từ / Số tiền đến**: so sánh bao gồm hai đầu trên `amount` của từng khoản. Nhập số trực tiếp, không kèm dấu phân cách hàng nghìn; có thể nhập tối đa hai chữ số thập phân. Không tự suy đoán số tiền.
- **Nhiều Tags**: chọn nhiều Tags trong workspace (tối đa 50; cho phép Tags đã lưu trữ). Khoản có **bất kỳ Tag nào khớp (OR)** được trả về một lần dù mang nhiều Tags đã chọn. **Tag ở cấp giao dịch cha không làm khớp toàn bộ khoản con**; chỉ xét Tag trực tiếp của từng khoản.

Các nhóm điều kiện có giá trị kết hợp **AND**; riêng nhiều Tags được chọn kết hợp **OR**. Có thể chỉ nhập đầu dưới hoặc đầu trên. Nếu nhập đủ hai đầu thì đầu dưới không được lớn hơn đầu trên. Sai kiểu dữ liệu, giờ/tiền sai định dạng hoặc khoảng ngược trả HTTP 400. Khoảng giờ **không tự vòng qua nửa đêm**; cần tìm thành hai khoảng riêng nếu muốn bao trùm giờ qua ngày.

Khi có bộ lọc, danh sách hiển thị riêng **số khoản khớp và tổng tiền của các khoản khớp**. Đây là số liệu tra cứu, không thay thế phần tổng/đối chiếu tiền đầy đủ của giao dịch ở đầu trang.

## Thao tác và bảo toàn dữ liệu

Rails áp dụng điều kiện trên các dòng **đã được giới hạn theo giao dịch/workspace được phép truy cập**, trước khi sắp xếp allowlist và phân trang 25 dòng. Khối chọn sắp xếp `line-item-sort-controls` đã được bỏ. Trên màn hình rộng vẫn có thể bấm tiêu đề các cột để sắp xếp; link sắp xếp và phân trang đều giữ Tags và các điều kiện lọc. Thay điều kiện lọc bắt đầu từ trang đầu; Xóa bộ lọc giữ lại thứ tự đang xem. Mặc định vẫn theo vị trí gốc.

Modal thêm/sửa qua Turbo, nhập CSV trong bản nháp, xóa và chuyển hướng giữ các điều kiện, kể cả từng giá trị `tag_ids[]`. Sau khi sửa/thêm, danh sách lọc được cập nhật; nếu khoản không còn khớp thì biến mất khỏi kết quả. Nếu khoản mới không khớp, có đường dẫn xem khoản đó ngoài bộ lọc. Khoản đã xác nhận vẫn khóa theo quy trình điều chỉnh cũ.

Không thay đổi bảng sáu cột, ngày giao dịch cấp cha, vị trí gốc, Tags, revision hoặc chứng từ bất biến. Không tạo migration, không chạy OCR/GGUF.

## Kiểm thử

Integration tests kiểm tra nhiều Tags theo OR, chống đếm trùng, Tags ngừng sử dụng, từ chối Tags workspace khác, tham số sai, giữ Tags trong liên kết/modal, Turbo edit; đồng thời bao phủ tên khoản không phân biệt hoa/thường, khoảng giờ/tiền bao gồm biên, điều kiện kết hợp, giờ thiếu, sắp xếp/phân trang, kết quả rỗng, dữ liệu đầu vào sai, Turbo modal và phân quyền workspace. Đây không phải chứng nhận production/kế toán.
