# Hiển thị ảnh các phiên bản chứng từ — 31/10/2026

Trước đây, mục **Các phiên bản chứng từ** ở trang chi tiết transaction chỉ liệt kê liên kết phiên bản và SHA256. Mục này còn bị thu gọn mặc định, khiến người dùng có thể tưởng rằng chỉ còn dữ liệu lịch sử mà không có ảnh.

**Cải tiến:** khi có chứng từ, mục này tự mở và hiển thị ảnh thu nhỏ theo bố cục responsive. Bấm ảnh sẽ mở trang chi tiết của đúng phiên bản để xem hoặc mở ảnh gốc được bảo vệ. Mỗi thẻ còn có số phiên bản, tên file, SHA256 và nhãn của ảnh đang được chọn. Ảnh sử dụng route riêng đã xác thực và kiểm tra quyền workspace, không tạo URL lưu trữ công khai mới. Không thay đổi transaction, chứng từ, lịch sử hoặc bản ghi Active Storage.

**Đã kiểm tra transaction #6:** cả hai file PNG đều tồn tại; SHA256 tính từ bytes thực tế khớp database. Đây là ảnh **mẫu kiểm thử UI**, bên trong ghi rõ “SAMPLE DOCUMENT — NOT A REAL RECEIPT”, không phải hóa đơn thật. Tôi giữ nguyên file gốc, không tự tạo ảnh thay thế và không suy đoán dữ liệu OCR.

Regression tests xác nhận có hai đường dẫn thumbnail, mục chứng từ tự mở, ảnh được trả qua route đã bảo vệ và SHA256 của bytes khớp. Nếu thiếu liên kết file, giao diện hiển thị thông báo thay vì giả định có ảnh. Không thay đổi quy tắc xác nhận bằng tay hoặc chính sách inference GGUF.
