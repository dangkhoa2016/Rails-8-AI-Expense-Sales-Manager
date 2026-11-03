# Giao diện workbench responsive cho khoản chi tiết

Trang `/finance/transactions/:id/line_items` ưu tiên bảng danh sách **ngay sau tiêu đề trang**, thay vì đặt ngày giao dịch, các thẻ đối chiếu tổng tiền, thông báo và nhóm nút thao tác phía trên danh sách.

## Bố cục

- **Màn hình rộng (từ 1280px):** chia ba cột. Sidebar trái chứa bộ lọc thu gọn hiện có (tên, giờ–phút, tiền, nhiều Tags của khoản). Khu vực giữa chứa bảng sáu cột, tổng kết khoản khớp và phân trang. Sidebar phải chứa ngày giao dịch dùng chung, bốn chỉ số đối chiếu đầy đủ, thông báo hiệu chỉnh và các thao tác/nhập CSV.
- **Màn hình trung bình (960–1279px):** chia hai cột. Bộ lọc và thông tin giao dịch cùng nằm trong một sidebar trái, xếp sát nhau và không bị chiều cao bảng kéo giãn; bảng nằm cột phải, có thể cuộn ngang **bên trong bảng** khi cần.
- **Màn hình hẹp (đến 959px):** thanh lọc thu gọn hiển thị trước, tiếp đến là thẻ khoản chi tiết responsive, cuối cùng là thông tin giao dịch và các thao tác. Thay đổi chỉ áp dụng cho trang khoản chi tiết, không làm ảnh hưởng bảng báo cáo hoặc danh mục Tags.

Thanh điều hướng chung, workspace, ngày giao dịch gốc và các số liệu đối chiếu vẫn được giữ nguyên. Turbo Stream tiếp tục cập nhật phần `#line_item_list` và khối KPI riêng, không làm mất trạng thái lọc ở sidebar. Biểu mẫu lọc GET chuyển đến neo `#line_item_results`; sắp xếp qua tiêu đề cột, phân trang, modal thêm/sửa và Tags đã chọn tiếp tục được bảo toàn.

## Kiểm chứng

Kiểm tra các độ rộng 375, 414, 768, 959, 960, 1024, 1199, 1280, 1366 và 1472px: không tràn ngang toàn trang, khoản đầu tiên xuất hiện trong viewport đầu, đúng thứ tự sidebar, bảng cuộn ngang độc lập ở độ rộng trung bình, lọc nhiều Tags không đổi, GET tự chuyển đến kết quả, và đầy đủ chế độ nháp/đã xác nhận. Chạy Rails full suite cùng kiểm tra tĩnh/bằng trình duyệt.

Đây chỉ là thay đổi giao diện: không chạy suy luận AI, không migration, không sửa giao dịch đã xác nhận và không tuyên bố đạt chuẩn production.

## Khoảng cách sidebar và tiêu đề cột (31/10/2026)

Trên màn hình 960–1279px, hai khối sidebar trái giờ dùng cùng một container độc lập, nên ngày giao dịch, KPI, thông báo và nút thao tác không còn bị kéo xuống cuối hàng Grid cao bằng bảng. Hai tiêu đề cột được rút gọn thành **Thời gian** và **Địa điểm**, nhưng tên trường chi tiết trong form thêm/sửa vẫn giữ nguyên.

Bộ lọc **mở sẵn theo mặc định** trên mọi kích thước. Ở màn hình tối đa 959px, phần form mở sẵn có giới hạn chiều cao, cuộn bên trong và nút Áp dụng luôn dễ tiếp cận; nhờ đó danh sách vẫn nằm trong vùng đầu màn hình. Người dùng vẫn có thể bấm tiêu đề để đóng bộ lọc; logic lọc nhiều Tags không đổi.

## Nghiệm thu sau khi Kaggle khởi động lại — 03/11/2026

Môi trường Kaggle được khôi phục đã PASS **136 Rails tests / 1.888 assertions** (không có failure, error hoặc skip), cùng kiểm tra tĩnh responsive và JavaScript. Chromium có đăng nhập đã kiểm tra 13 độ rộng (375, 414, 768, 900, 959, 960, 1024, 1122, 1199, 1279, 1280, 1366 và 1472 px). Ở mọi kích thước, bộ lọc mở sẵn, tiêu đề cột là Thời gian/Địa điểm, toàn trang không bị tràn ngang và khoản đầu tiên xuất hiện trong viewport cao 916 px. Ở độ rộng 960–1279 px, khoảng cách giữa bộ lọc và khối thông tin giao dịch ở sidebar khoảng 10 px. Đã kiểm tra lọc nhiều Tags và tự chuyển đến kết quả tại 375, 1122 và 1366 px.

Kiểm tra browser sử dụng database riêng được khôi phục từ một bản sao lưu dữ liệu tổng hợp (14 giao dịch, 282 khoản), không phải nguyên trạng database development trước khi reboot (trước đó ghi nhận 285 khoản). Không khẳng định khôi phục đầy đủ dữ liệu hoặc đã nghiệm thu production.

## Tinh gọn thông tin đối chiếu — 03/11/2026

Sidebar danh sách khoản chi tiết hiện chỉ còn **ba** giá trị: số khoản, tổng các khoản và tổng tiền giao dịch. Đã bỏ ô “Chênh lệch (giao dịch − các dòng)” luôn hiển thị và phần giải thích dài chiếm diện tích. Trên trang chi tiết giao dịch cũng không còn lặp ô chênh lệch ở phần thông tin chính.

Backend vẫn tính toán và đối soát số tiền. Thêm/sửa/xóa/nhập khoản trong bản nháp sẽ đồng bộ tổng theo các khoản, còn bước xác nhận các bản nháp được quản lý theo khoản phải kiểm tra tổng khớp. **Các giao dịch cũ, khoản điều chỉnh hợp lệ hoặc giao dịch không có dòng chi tiết không nhất thiết có chênh lệch bằng 0.** Khi có ít nhất một khoản và tổng giao dịch khác tổng các khoản, giao diện chỉ hiện *thông báo có điều kiện* “Số tiền ngoài danh sách khoản chi tiết”, không phải KPI thường trực. Số tiền đó có thể do phí, thuế, giảm giá hoặc điều chỉnh trước đây, cần đối chiếu chứng từ gốc. Giao dịch chưa có khoản chi tiết không hiện thông báo này. Việc hiển thị không sửa giao dịch đã xác nhận.

Trang chi tiết giao dịch dùng cùng cách thông báo có điều kiện. Turbo Stream vẫn cập nhật đúng phần `line_items_summary` với ba KPI. Phân quyền, sắp xếp, lọc nhiều Tags và dữ liệu kiểm toán lịch sử không thay đổi.

## Gộp tổng tiền và luôn hiển thị thao tác khoản — 03/11/2026

Không hiển thị lặp **Tổng các dòng chi tiết** và **Số tiền giao dịch** khi hai giá trị bằng nhau. Với giao dịch đã chia khoản và tổng khớp, sidebar chỉ hiển thị **Số khoản chi tiết** và **Số tiền giao dịch**. Khi có ít nhất một khoản và thực sự tồn tại chênh lệch (ví dụ phí hoặc giảm giá trước đây), vẫn hiển thị cả hai tổng cùng ghi chú điều chỉnh chỉ đọc. Giao dịch chưa có khoản thì không hiển thị tổng khoản bằng 0 dư thừa. Đây chỉ là thay đổi trình bày; tổng tiền trong database, quy tắc đối soát và dữ liệu giao dịch đã xác nhận không đổi.

Trong workbench hai cột ở **960–1559px**, phần giữa có thể không đủ rộng để nhìn toàn bộ sáu cột. Vì vậy từ **1199px trở xuống**, danh sách chuyển sang **thẻ khoản chi tiết responsive**, bảo đảm nút thao tác hiển thị trọn vẹn bên trong thẻ, không bị cắt ở mép phải. Từ **1200px trở lên** giữ bảng; ba cột workbench chỉ xuất hiện từ **1560px** để bảng giữa có đủ không gian. Vẫn giữ nguyên ID dòng, Turbo modal, Tags, bộ lọc, URL sắp xếp và phân trang 25 khoản.

Trong **bản nháp**, mỗi khoản có đủ nút **Sửa chi tiết khoản** và **Xóa**. Với **giao dịch đã xác nhận**, không có xóa trực tiếp vì giao dịch gốc là bất biến; cần tạo bản hiệu chỉnh trước, rồi xóa khoản trong bản nháp hiệu chỉnh đó. Giao diện có ghi chú ngắn ngay phía trên danh sách và vẫn hiển thị nút Sửa để bắt đầu luồng hiệu chỉnh.

QA: full Rails suite và Chromium có đăng nhập tại 15 độ rộng (375, 414, 768, 959, 960, 998, 1024, 1122, 1199, 1200, 1280, 1366, 1472, 1560 và 1600px), gồm số tiền khớp/không khớp và trạng thái nút của giao dịch nháp/đã xác nhận.
