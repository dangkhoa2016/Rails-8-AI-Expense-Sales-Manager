# Tạo giao dịch từ ảnh hóa đơn và kiểm tra thủ công (M9)

## Luồng sử dụng

Chế độ **Chi tiền** tại `/finance/transactions/new?kind=expense` ưu tiên **tải ảnh hóa đơn** (JPEG/PNG/WEBP, tối đa 10 MB). Người dùng chọn Thu/Chi, chọn ảnh từ thiết bị hoặc thả vào vùng upload, nhấn **Tải ảnh và tiếp tục**. **Không phải nhập ngày, số tiền, mô tả, danh mục, cửa hàng hoặc từng khoản trước khi tải ảnh.** Trình duyệt chỉ hiện ảnh xem trước; không đọc hoặc phân tích dữ liệu ảnh.

Endpoint `POST /finance/transactions/from_receipt` dùng `Finance::ReceiptIntake`, tạo **bản nháp trống, chưa xác nhận**, rồi đưa ảnh qua `Finance::UploadDocument` để kiểm tra định dạng, kích thước và lưu ảnh gốc với SHA256, MIME, dung lượng cùng thông tin phiên bản. Nếu ảnh lỗi thì rollback việc tạo draft; không để lại bản nháp tài chính trống do upload lỗi. Không tự suy đoán thông tin tiền, ngày hoặc tên hàng; upload không đưa giao dịch vào báo cáo đã chốt.

Sau khi tải thành công, chuyển đến `/finance/transactions/:id/review`. Màn hình kiểm tra hiển thị ảnh thật, các trường ngày, số tiền, mô tả, danh mục, thông tin phụ tùy chọn, đề xuất AI nếu đã lưu và liên kết đến modal sửa từng khoản. Lưu chỉnh sửa vẫn ở màn hình kiểm tra; xác nhận giao dịch là **bước riêng do con người chủ động thực hiện**. Người dùng vẫn có thể thêm chứng từ vào giao dịch từ trang chi tiết.

## Giới hạn AI hiện tại (quan trọng)

**Tải ảnh hiện chưa kích hoạt inference Qwen3-VL GGUF trực tiếp trong Rails demo.** GPU đã tắt. Giao diện không giả lập dữ liệu đọc được, không hiện tiến trình AI giả, không tự điền số tiền hay cửa hàng. Khi chưa có gợi ý từ model đã được ghi nhận, màn hình nói rõ adapter vision chưa kết nối. Nếu có gợi ý đã lưu với bằng chứng, đây chỉ là **đề xuất chưa xác nhận**, không tự ghi số tiền vào giao dịch. Chính sách dự án cấm OCR tự viết, regex hoặc heuristic hard-code theo ảnh. Trường không đọc được để NULL và cho phép tải ảnh rõ hơn hoặc nhập dữ liệu đã xác minh.

Đây là luồng **tải trước – đối chiếu – xác nhận** đang hoạt động, chưa phải tuyên bố AI đã tự động đọc hóa đơn. Để tự động hóa đầy đủ cần adapter GGUF có xác thực, nguồn gốc prompt/model SHA256 và bài test nhận diện thực tế.

## Nhập thủ công dự phòng

Trang tải ảnh vẫn có mục **Nhập thủ công khi không có ảnh** ở trạng thái thu gọn. Hai cách tạo draft đều giữ nguyên bảo vệ bất biến giao dịch đã chốt, cô lập workspace, tên danh mục song ngữ và công thức báo cáo.

## Kiểm thử

Integration tests kiểm tra form EN/VI, lưu ảnh và provenance, audit, rollback ảnh lỗi, cập nhật draft trên trang review, ngăn xác nhận tự động, phân quyền workspace và nhập thủ công dự phòng.
