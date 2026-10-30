# Thêm khoản chi nhanh, tính thành tiền tức thì và dùng nhiều Tags (M11)

## Trải nghiệm chính

Nút **+ Thêm một khoản chi** mở modal Turbo. Người dùng chỉ cần tập trung vào tên khoản và phần tính tiền. **Số lượng mặc định là 1**, còn đơn giá để trống cho đến khi nhập. Khi có cả số lượng và đơn giá, mỗi lần gõ hoặc sửa một trong hai trường sẽ tự tính **thành tiền = số lượng × đơn giá** (làm tròn hai chữ số thập phân). Thành tiền tạm khóa chỉnh tay khi phép tính đầy đủ; nếu không có đơn giá thì vẫn cho nhập trực tiếp thành tiền.

Phép tính trên trình duyệt chỉ để hiển thị nhanh. Rails **tính lại độc lập ở backend** khi lưu từng khoản từ modal; không tin tổng gửi lên nếu số lượng và đơn giá đã được cung cấp. Import CSV thủ công vẫn tuân theo cột `amount` của tệp; ứng dụng không đoán đơn giá từ ảnh bằng parser. Tổng tiền bản nháp tự đồng bộ theo các dòng sau khi tạo/sửa/xóa/import thành công, nếu còn dòng. Việc thay đổi có audit và không tự xác nhận; người dùng có thể chỉnh tổng cho thuế/giảm giá trước khi chốt.

## Ngày dùng chung và giờ riêng tùy chọn

Modal Thêm/Sửa khoản hiển thị ngày từ `transaction.transaction_date`, không có ô ngày riêng và không tự gán ngày hôm nay. Nếu giao dịch nháp chưa có ngày, giao diện thông báo chưa nhập; người dùng phải điền ngày ở form giao dịch trước khi chốt. Giờ và địa điểm từng khoản là tùy chọn, không tự lấy giờ máy. Cột lịch sử `occurred_on` được giữ để truy vết nhưng không còn là ngày có hiệu lực.

## Chọn nhiều Tags và tạo mới ngay khi lưu

Mỗi khoản có thể chọn **nhiều Tags** qua các chip lựa chọn. Khi chưa có tag phù hợp, nhập tên tại ô **Tạo tags mới**, có thể nhập nhiều tên cách nhau bằng dấu phẩy. Mỗi lần lưu tối đa 12 tags và tối đa 6 tên mới. Tags mới thuộc workspace đang đăng nhập; tên người dùng nhập tạm thời dùng chung cho EN và VI, có thể sửa bản dịch riêng tại trang **Quản lý Tags** (`/finance/tags`). Hệ thống không tuyên bố tự dịch AI.

Việc tạo tag, liên kết tag, lưu khoản và tạo audit được gói trong **một transaction PostgreSQL**. Tag từ workspace khác bị từ chối. Trigger trong DB ngăn sửa/xóa/thêm liên kết tag vào khoản của giao dịch đã xác nhận. Khi điều chỉnh khoản đã chốt, hệ thống tạo **bản nháp thay thế**, sao chép tags cũ và không sửa bản gốc. Các bản ghi có danh mục đơn cũ vẫn được bảo toàn; migration gắn tags tương ứng nếu tìm được mã trong catalog.

**Tag được chọn đầu tiên** vẫn là mã danh mục chính để tương thích với báo cáo hiện có. Các tags còn lại để phân loại, **không nhân đôi số tiền** trong báo cáo. Nếu sau này cần phân bổ một khoản tiền vào nhiều danh mục phải làm mô hình báo cáo phân bổ riêng.

## Kiểm thử và giới hạn

Integration tests kiểm tra ngày dùng chung và giờ riêng tùy chọn, tính tiền ở backend, chọn/tạo nhiều tags, tái sử dụng tag cũ, chặn thao tác khác workspace, rollback, trigger bảo vệ dữ liệu và bản nháp điều chỉnh. Node test kiểm tra phép tính trên giao diện. Demo CPU **chưa kích hoạt inference AI đọc ảnh**.

Hiện multi-tag áp dụng cho **modal Thêm/Sửa từng khoản**. Trường danh mục chính cấp transaction vẫn được giữ để tương thích báo cáo; thay đổi này không tự chuyển mọi báo cáo sang phân bổ nhiều tags.


## Tương tác popup và checkbox

Popup Thêm/Sửa không tự đóng khi click nền tối hoặc nhấn Escape. Dùng biểu tượng × được căn giữa hoặc nút Hủy để bỏ thao tác chưa lưu. Khi lưu thành công, Turbo Stream vẫn đóng popup, cập nhật đúng dòng khoản chi và tổng đối chiếu. Checkbox trạng thái trong sidebar Quản lý Tags có kích thước chuẩn và nhãn dễ nhấp.


## Danh sách khoản chi responsive

Trên desktop rộng, hệ thống vẫn dùng bảng bảy cột như trước. Với viewport dưới 1.200px, **riêng bảng danh sách từng khoản chi** sẽ chuyển thành các thẻ tự co giãn (hai thẻ mỗi hàng khi đủ rộng, một thẻ mỗi hàng trên điện thoại). Mỗi thẻ tách rõ số thứ tự, tên và Tags, số tiền, ngày/giờ/địa điểm, đồng thời hiển thị đủ nút **Sửa / Xóa** mà không cần cuộn ngang. Các trường phụ không có giá trị được ẩn bớt trên thẻ nhỏ.

HTML vẫn dùng hàng bảng có `id=finance_line_item_<id>`, nhờ đó Turbo Streams tiếp tục **cập nhật đúng khoản vừa sửa**, hoặc thay cả danh sách khi tạo/xóa. Header bảng vẫn có thể được đọc bằng công cụ trợ năng; phân trang giữ **25 khoản/trang** và liên kết như cũ. CSS chỉ tác động danh sách khoản chi, không sửa bảng báo cáo, Tags hoặc CSV. Ngày, Giờ và Địa điểm có nhãn ngắn theo VI/EN. Thay đổi responsive không ảnh hưởng phép tính; quy tắc tổng tiền bản nháp là phần cập nhật riêng.

Ở màn hình tối đa 420px, các nút thao tác chiếm hàng riêng sau ngày/giờ/địa điểm, không che mất giờ đã nhập của khoản chi.
