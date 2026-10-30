# Trải nghiệm và báo cáo tài chính — Tiếng Việt

> **Lưu ý cập nhật (30/10/2026):** Một số mô tả danh mục trong giai đoạn này là thiết kế lịch sử. Hiện hành chỉ dùng Tags; không còn cột danh mục đơn. Xem [đặc tả Tags-only](TAGS_ONLY_SCHEMA.vi.md).


## Quy trình thu chi

Trang giao dịch hiển thị tổng thu, tổng chi đã xác nhận trong tháng, chênh lệch thu chi và số bản nháp. Bảng giao dịch có tìm kiếm theo nội dung, lọc trạng thái/loại và phân trang trong phạm vi workspace.

Người dùng có thể tạo khoản thu/chi thủ công, không bắt buộc có ảnh. Muốn chốt giao dịch phải xác nhận ngày phát sinh và số tiền dương. Bản ghi đã chốt không bị sửa âm thầm. Ảnh tải lên được lưu thành phiên bản riêng bất biến, có SHA256; sau khi chốt vẫn có thể thêm ảnh làm bằng chứng bổ sung.

## Báo cáo theo tháng

Chọn tháng để xem bốn chỉ số: tổng thu, tổng chi, chênh lệch và số giao dịch đã xác nhận. Các thẻ thu/chi thể hiện thêm số liệu tháng trước. Xu hướng sáu tháng và bảng phát sinh hằng ngày được nhóm theo **ngày giao dịch do người dùng xác nhận**, không dùng ngày tải ảnh hoặc tạo bản ghi. Biểu đồ danh mục chỉ tính khoản chi đã xác nhận trong tháng. Giao dịch gần đây có đường dẫn về hồ sơ và chứng từ.

CSV chỉ chứa giao dịch đã chốt thuộc workspace hiện tại; số tiền giữ định dạng máy đọc được, đồng thời bảo vệ trước công thức bảng tính độc hại. Bản nháp và đề xuất AI chưa duyệt không làm thay đổi báo cáo.

## Ngôn ngữ và hướng dẫn

Dùng EN / VI trên thanh điều hướng. Hai bộ dịch Rails I18n nằm riêng tại `config/locales/en.yml` và `config/locales/vi.yml`. Ngôn ngữ được lưu bằng signed cookie. Đổi giao diện không đổi ngày và số tiền trong cơ sở dữ liệu.

Trang Hướng dẫn giải thích nhập tay khi AI không đọc được, lưu phiên bản ảnh, xác nhận theo trường, khóa dữ liệu và cách tổng hợp báo cáo.

## Giới hạn

Adapter GGUF vẫn tắt cho đến khi qua kiểm thử chất lượng. Đây chưa phải phần mềm kế toán hoặc tồn kho production. Xuất PDF/cả năm, chính sách tài chính theo địa phương, phân quyền đa vai trò và điều chỉnh giao dịch đã chốt là những mục tiếp theo. Quick Tunnel chỉ sử dụng với dữ liệu giả lập.
