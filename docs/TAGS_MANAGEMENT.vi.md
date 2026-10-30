# Quản lý Tags riêng theo workspace

Mở `/finance/tags` để tạo, sửa, lưu trữ hoặc kích hoạt lại Tags. Mỗi Tag có mã `key` không đổi, tên tiếng Việt và tiếng Anh riêng. Một transaction hoặc `line_item` có thể gắn nhiều Tags. Hệ thống không còn dropdown danh mục đơn, cột `category` và route cũ `/finance/categories`.

Không cho đổi mã khi Tag đã tạo; người dùng có thể sửa tên VI/EN và nhãn mới được hiển thị trên các hồ sơ lịch sử. Khi Tag đã được dùng, thao tác xóa chuyển sang lưu trữ thay vì mất liên kết; Tag chưa dùng có thể xóa. Tag lưu trữ vẫn hiển thị trên giao dịch cũ nhưng không thể gắn mới. Phân quyền workspace được kiểm tra trong Rails và trigger PostgreSQL.

Xem [cấu trúc Tags-only và cách bảo toàn dữ liệu](TAGS_ONLY_SCHEMA.vi.md).
