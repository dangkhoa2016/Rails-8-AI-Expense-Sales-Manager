# Cấu trúc tài chính chỉ sử dụng Tags — quy tắc migration

## Vì sao bỏ cột danh mục đơn

Trước đây, transaction và từng `line_item` vẫn giữ chuỗi `category`, song song với quan hệ nhiều Tags mà người dùng đã chọn. Hai nguồn phân loại dễ gây lệch báo cáo và hiển thị thừa.

**Cấu trúc hiện hành:** `finance_tags` chứa mã Tag, tên EN/VI riêng, workspace và trạng thái; `finance_transaction_tags(transaction_id, tag_id)` và `finance_line_item_tags(line_item_id, tag_id)` là các liên kết nhiều–nhiều. Hai bảng `finance_transactions`, `finance_line_items` **không còn cột `category`**. Bảng `finance_categories` trước đây đã được **đổi tên**, không xóa các nhãn lịch sử. Model Rails sử dụng `Finance::Tag`.

## Bảo toàn dữ liệu và kiểm toán

Migration `20261030200500_replace_legacy_categories_with_tags.rb` **không hỗ trợ rollback ngược** vì cột cũ đã bị loại bỏ, nên phải sao lưu PostgreSQL trước khi chạy. Migration bổ sung những Tag cũ chưa có trong bảng nhãn, dùng mã an toàn và không ghi đè bản dịch người dùng đã chỉnh sửa. Trước khi bỏ cột, migration thêm liên kết Tags còn thiếu cho các transaction/line item, **bao gồm dữ liệu đã confirmed**, chỉ dưới dạng metadata phân loại. Trigger ngăn sửa liên kết Tags trên bản confirmed được tạm tắt trong chính DB transaction này, chỉ để thêm metadata cũ, sau đó bật lại. **Không thay đổi tiền, ngày, trạng thái giao dịch, chứng từ, các khoản chi tiết, JSON lịch sử phiên bản hay audit logs.** Kiểm tra mọi bản ghi có giá trị cũ đều có liên kết trước khi bỏ cột. Các nhãn đã có nhiều lựa chọn vẫn được giữ.

Không chỉnh sửa JSON audit/revision lịch sử vì đó là bằng chứng gốc. Các file migration trước đây vẫn thuộc lịch sử Git để tạo database mới theo đúng chuỗi migration.

## Báo cáo và CSV

Báo cáo ở cấp giao dịch và cấp khoản chi tiết phân bổ mỗi số tiền theo **Tag đầu tiên được gắn** (link ID nhỏ nhất). Những Tags khác chỉ là nhãn bổ sung, không làm tổng tiền bị cộng nhiều lần. Bản ghi không có Tag được tính trong nhóm chưa gắn nhãn. Khi đã correction, báo cáo chỉ tính giao dịch confirmed đang có hiệu lực. File CSV xuất dùng cột **Tags** chứa các mã ngăn cách bằng dấu chấm phẩy, không dùng Category. CSV nhập khoản có hai cột bắt buộc `description,amount` và các cột tùy chọn `quantity,unit_price,tags,occurred_time,location_text`. Mã Tags phải có trong workspace; sai/mã của workspace khác thì từ chối toàn bộ import, không suy đoán nhãn. Cột ngày CSV cũ `occurred_on` chỉ hợp lệ khi trùng ngày transaction cha.

## Các bước kiểm chứng

- Sao lưu database development thành file riêng tư, lưu SHA256 và số lượng bản ghi/tổng tiền.
- Khôi phục bản sao DB độc lập rồi thử migration trên **bản sao** trước khi đụng đến preview.
- So sánh số tiền, trạng thái confirmed, liên kết correction và bằng chứng bất biến trước/sau; kiểm tra đầy đủ Tags được chuyển.
- Kiểm tra trigger bảo vệ bản confirmed và báo cáo không cộng trùng khi chọn nhiều Tags.
- Chạy Rails tests, Node tests và kiểm tra giao diện bằng browser có đăng nhập.
- Chỉ nâng cấp DB preview khi tất cả cổng kiểm chứng PASS.

Dữ liệu tài chính trong demo là giả lập; chưa bật GGUF vision inference và chưa tuyên bố chứng nhận hệ thống kế toán production.
