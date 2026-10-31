# Giao diện workbench responsive cho khoản chi tiết

Trang `/finance/transactions/:id/line_items` ưu tiên bảng danh sách **ngay sau tiêu đề trang**, thay vì đặt ngày giao dịch, các thẻ đối chiếu tổng tiền, thông báo và nhóm nút thao tác phía trên danh sách.

## Bố cục

- **Màn hình rộng (từ 1280px):** chia ba cột. Sidebar trái chứa bộ lọc thu gọn hiện có (tên, giờ–phút, tiền, nhiều Tags của khoản). Khu vực giữa chứa bảng sáu cột, tổng kết khoản khớp và phân trang. Sidebar phải chứa ngày giao dịch dùng chung, bốn chỉ số đối chiếu đầy đủ, thông báo hiệu chỉnh và các thao tác/nhập CSV.
- **Màn hình trung bình (960–1279px):** chia hai cột. Bộ lọc và thông tin giao dịch xếp dọc trong cột trái; bảng nằm cột phải, có thể cuộn ngang **bên trong bảng** khi cần.
- **Màn hình hẹp (đến 959px):** thanh lọc thu gọn hiển thị trước, tiếp đến là thẻ khoản chi tiết responsive, cuối cùng là thông tin giao dịch và các thao tác. Thay đổi chỉ áp dụng cho trang khoản chi tiết, không làm ảnh hưởng bảng báo cáo hoặc danh mục Tags.

Thanh điều hướng chung, workspace, ngày giao dịch gốc và các số liệu đối chiếu vẫn được giữ nguyên. Turbo Stream tiếp tục cập nhật phần `#line_item_list` và khối KPI riêng, không làm mất trạng thái lọc ở sidebar. Biểu mẫu lọc GET chuyển đến neo `#line_item_results`; sắp xếp qua tiêu đề cột, phân trang, modal thêm/sửa và Tags đã chọn tiếp tục được bảo toàn.

## Kiểm chứng

Kiểm tra các độ rộng 375, 414, 768, 959, 960, 1024, 1199, 1280, 1366 và 1472px: không tràn ngang toàn trang, khoản đầu tiên xuất hiện trong viewport đầu, đúng thứ tự sidebar, bảng cuộn ngang độc lập ở độ rộng trung bình, lọc nhiều Tags không đổi, GET tự chuyển đến kết quả, và đầy đủ chế độ nháp/đã xác nhận. Chạy Rails full suite cùng kiểm tra tĩnh/bằng trình duyệt.

Đây chỉ là thay đổi giao diện: không chạy suy luận AI, không migration, không sửa giao dịch đã xác nhận và không tuyên bố đạt chuẩn production.
