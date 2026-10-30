# Danh mục song ngữ theo workspace (M8)

## Mục đích và bảo toàn dữ liệu

Ứng dụng có trang **Quản lý danh mục** tại `/finance/categories`, hỗ trợ tạo, xem danh sách, sửa, xóa hoặc lưu trữ. Mỗi danh mục có **mã cố định**, **tên tiếng Việt** và **tên tiếng Anh** riêng. Danh mục chỉ thuộc một workspace; không được đọc/sửa từ workspace khác.

Các cột `finance_transactions.category` và `finance_line_items.category` vẫn giữ nguyên **mã chuỗi** trước đây. Nhờ vậy không sửa giao dịch đã xác nhận, không thay báo cáo hoặc giá trị CSV. Khi đổi ngôn ngữ giao diện, hệ thống đổi **nhãn hiển thị** nhưng giữ mã lưu trong DB. Form giao dịch và modal thêm/sửa khoản chi có danh sách chọn danh mục. Mã danh mục cũ được đăng ký tự động trong catalog của workspace, không viết lại dữ liệu lịch sử. Nếu mã cũ chưa có bản dịch, tên tạm thời giống nhau ở hai ngôn ngữ, chờ người dùng điều chỉnh.

Mã chỉ gồm chữ thường không dấu, chữ số, dấu gạch dưới (2–50 ký tự, bắt đầu bằng chữ); **không sửa mã sau khi tạo**. Bắt buộc tên EN/VI, cho phép đổi cả hai tên. Mã chỉ phải duy nhất **trong cùng workspace**.

## Xóa và lưu trữ

Danh mục **chưa từng dùng** được xóa hẳn khỏi catalog. Danh mục đã tham chiếu trong transaction (nháp hoặc đã chốt) hoặc bất kỳ line item nào sẽ **được lưu trữ** (`active=false`) khi bấm Xóa. Danh mục lưu trữ không hiện trong lựa chọn cho giao dịch mới nhưng vẫn có nhãn hiển thị trong giao dịch và báo cáo cũ; có thể mở sửa để kích hoạt trở lại. Tạo lại catalog mẫu sẽ không bật lại danh mục đã lưu trữ hay ghi đè tên do người dùng đặt.

Danh mục mẫu chỉ là tên chung phục vụ demo; không xác thực một khoản thanh toán thực tế.

## Cải tiến giao diện

Form nhập thủ công tập trung các trường: thu/chi, ngày, số tiền, danh mục và mô tả; từ M9, trang tạo giao dịch ưu tiên tải ảnh hóa đơn trước, còn form này là phương án dự phòng. Giờ, địa điểm và nội dung bổ sung ở mục **Thông tin tùy chọn** có thể mở khi cần. Người dùng lưu bản nháp trước, sau đó thêm hàng hóa và chứng từ từ trang chi tiết bằng modal, tránh form dài.

Trang chi tiết giao dịch tập trung vào số tiền, trạng thái, danh mục và đối chiếu tổng dòng. Chỉ xem trước tối đa 5 khoản chi, có nút mở toàn bộ danh sách phân trang. Chứng từ, thông tin phụ và lịch sử audit nằm trong những mục mở rộng. Việc xác nhận bởi con người và bảo toàn giao dịch đã chốt vẫn giữ nguyên.

Tính năng này không bổ sung kế toán thuế hoặc thay đổi công thức tính số tiền.


## Chuyển sang mô hình nhiều Tags

Từ M11, giao diện menu và trang quản lý dùng tên **Tags**, trong khi bảng `finance_categories` và URL `/finance/categories` vẫn giữ để tương thích. Mỗi **line item** được chọn nhiều tags hoặc tạo tags mới ngay trong modal Thêm/Sửa. Báo cáo theo danh mục chính cấp giao dịch vẫn dùng một mã để không cộng trùng tiền. Xem [quy trình nhập khoản nhanh và nhiều Tags](QUICK_ITEM_TAGS.vi.md).
