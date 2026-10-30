# Hai quy trình thu/chi riêng biệt, cùng chuẩn UI/UX (M10)

## Mục tiêu

**Chi tiền** và **Thu tiền** là hai nghiệp vụ khác nhau nên không dùng một form dài giống hệt nhau. Cả hai vẫn dùng chung typography, điều hướng, kiểm tra dữ liệu và quy tắc xác nhận an toàn. **Không xóa hoặc viết lại cột ledger cũ**; giao dịch đã chốt vẫn bất biến, chỉnh sửa phải dùng bản nháp điều chỉnh có audit.

## Chi tiền — ưu tiên hóa đơn

Mở `/finance/transactions/new?kind=expense` hoặc tab **Chi tiền**. Hành động chính là **tải ảnh hóa đơn**. Ảnh JPEG/PNG/WEBP gốc được lưu với phiên bản và SHA256; một bản nháp chưa có số tiền/ngày được tạo trước khi người dùng nhập bất kỳ giá trị tài chính nào. Màn hình kiểm tra khoản chi hiển thị ảnh thật, ngày, số tiền, nội dung và danh mục tùy chọn. Các mặt hàng được quản lý qua modal Turbo riêng từng dòng, dùng ngày chung của giao dịch, còn giờ và địa điểm từng khoản là tùy chọn.

Nếu không có ảnh, mục **nhập khoản chi nhanh** được thu gọn: số tiền và nội dung; ngày thực tế và danh mục nằm trong phần tùy chọn. Trước khi **xác nhận giao dịch**, hệ thống vẫn yêu cầu ngày thực tế và số tiền dương.

## Thu tiền — ưu tiên số tiền nhận

Mở `/finance/transactions/new?kind=income` hoặc tab **Thu tiền**. Form chính có **ba trường**: số tiền đã nhận, nguồn thu/nội dung, ngày thực tế. Backend kiểm tra cả ba trước khi lưu qua luồng nhập nhanh, kể cả khi bỏ qua kiểm tra HTML. Không tự gán ngày hôm nay hoặc đoán tiền từ thông tin khác. Danh mục nằm trong mục tùy chọn.

Tính năng upload ảnh chứng từ thu tiền được mở sẵn với khu vực chọn ảnh/kéo thả tương tự khoản chi; ảnh tạo bản nháp thu trống, không suy đoán tiền/ngày. Sau khi đã lưu bản nháp thu tiền, người dùng có thể **đính kèm chứng từ vào chính bản nháp đó** từ màn hình kiểm tra, tránh tạo transaction trùng.

Trang kiểm tra khoản thu tập trung vào số tiền, nguồn thu và ngày. Danh sách item chỉ cần dùng khi một lần nhận tiền gồm nhiều khoản. Sau thao tác sửa dòng chi tiết, tổng giao dịch nháp có dòng còn lại sẽ tự đồng bộ; người dùng có thể điều chỉnh tổng thủ công và đối chiếu trước khi xác nhận.

## Bỏ các trường gây phiền trong giao diện

Các trường giờ, địa điểm và nội dung giải thích chung không còn xuất hiện mặc định khi tạo mới hoặc kiểm tra. Dữ liệu cũ vẫn được giữ, tiếp tục truy cập qua đường chỉnh sửa đã có. Danh mục có mã cố định, nhãn EN/VI riêng và thuộc workspace.

## Ranh giới AI

Bản demo hiện chạy CPU và **chưa có adapter inference Qwen3-VL GGUF trực tiếp**. Upload không tự đọc hay dựng dữ liệu ảnh giả. Đề xuất AI đã có bằng chứng (nếu có) luôn được đánh dấu chưa xác nhận; chỉ người dùng mới được chốt giá trị tài chính. Đây là cải tiến trải nghiệm chứ **không phải tuyên bố OCR AI đã hoạt động**.

## Tương thích và kiểm thử

Giữ nguyên xác thực, phân quyền workspace, audit, lịch sử, báo cáo và quy trình xác nhận. Test kiểm tra giao diện và chuyển chế độ EN/VI, xác thực thu tiền nhanh, thu tiền có chứng từ, chi tiền từ ảnh, trang review khác nhau và chặn tự chốt số tiền.
