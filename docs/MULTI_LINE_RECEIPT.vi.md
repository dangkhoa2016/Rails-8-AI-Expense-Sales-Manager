# M6 — Hóa đơn nhiều dòng và nhập hàng loạt (Tiếng Việt)

## Mô hình dữ liệu

Một giao dịch thu/chi có thể chứa **0–500 dòng khoản chi tiết**, không phải 500 bút toán tài chính độc lập. Số tiền và ngày trong giao dịch cha được người dùng xác nhận; mỗi dòng có tên hàng, thành tiền và các trường tùy chọn như số lượng, đơn giá, danh mục. Giờ và địa điểm vẫn là tùy chọn ở cấp giao dịch.

**Không tự suy tổng tiền giao dịch** từ tổng các dòng hoặc từ ảnh hóa đơn. Tổng các dòng chỉ được so sánh với số tiền cha; chênh lệch có thể do thuế, khuyến mãi, phí hoặc dòng chưa đọc được. Báo cáo thu/chi chỉ tính **một lần** mỗi giao dịch đã xác nhận. Bảng phân bổ danh mục theo dòng được hiển thị riêng và có chênh lệch với tổng chi đã chốt; không cộng dòng lần thứ hai vào báo cáo chính.

## Nhập tay và import CSV

Với bản nháp ngắn, nút **Thêm dòng mới** dùng Stimulus để tạo dòng trực tiếp. Hóa đơn nhiều dòng được quản lý ở trang Khoản chi tiết, phân trang 25 dòng, có thể sửa từng tên hàng, danh mục, thành tiền, số lượng và đơn giá. Form cha không cần tải cùng lúc 100 ô nhập.

Có thể dùng `examples/receipt_lines_100.csv` hoặc CSV UTF-8 theo mẫu:

```csv
description,amount,quantity,unit_price,category
Bánh mì ngọt,30000,2,15000,food
Giấy in A4,85000,1,85000,office
```

Hai cột bắt buộc là `description` và `amount`; các cột `quantity`, `unit_price`, `category` là tùy chọn. Không nhận cột lạ hoặc cột trùng. Số lượng (nếu có) phải dương; đơn giá và thành tiền không âm; thành tiền có tối đa hai chữ số thập phân; tên khoản không rỗng và tối đa 500 ký tự. Giới hạn mỗi tệp 512 KiB và 500 dòng, đồng thời mỗi giao dịch có tối đa 500 dòng. CSV dùng dấu chấm thập phân để máy đọc ổn định.

Hệ thống kiểm tra **toàn bộ** CSV trước khi ghi. Tất cả dòng, SHA256 của lượt import và audit được lưu nguyên tử dưới transaction lock; lỗi sẽ rollback toàn bộ. Nhập lại **chính xác cùng byte CSV** không tạo dữ liệu trùng. Chỉ tài khoản có quyền trong workspace mới được import khi giao dịch còn nháp.

CSV có nội dung khác được xem là lượt import mới và sẽ **thêm dòng**, không âm thầm thay thế dòng đã có. Muốn thay, hãy sửa hoặc xóa những dòng cũ trong trang quản lý bản nháp. Số lượng và đơn giá không tự tính lại thành tiền đã nhập.

## Đề xuất AI và an toàn

Adapter AI llama.cpp/GGUF **chưa được bật** trên demo. Nếu hệ thống đã lưu output cấu trúc từ một lượt nhận diện trước đó, trang Đề xuất AI có thể hiển thị và phân trang hơn 100 nhóm dòng, cho phép chấp nhận/từ chối từng trường. Duyệt đề xuất **không tự thêm khoản chi** và không ghi nhận tài chính; người dùng phải kiểm tra rồi nhập hoặc import dữ liệu đã xác minh. Không dùng parser OCR hoặc heuristic tự suy số, ngày, tổng tiền từ ảnh.

## Seed dữ liệu và kiểm thử

Script tùy chọn tạo **bốn hóa đơn hoàn toàn giả lập có 5, 20, 50 và 100 dòng**, không kèm ảnh hóa đơn thực:

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails runner script/seed_demo_itemized_receipts.rb
```

Script chỉ chạy development, yêu cầu tài khoản demo riêng đã tồn tại, có thể chạy lại không tạo trùng. Mẫu 50 dòng cố tình có một khoản chênh lệch minh họa để kiểm tra UX đối chiếu; mẫu 100 dòng cân bằng. Không sửa dữ liệu tài chính đã chốt trước đó.

```bash
bin/rails db:prepare
bin/rails test
ruby tests/test_input_policy.rb
```

**Chưa hoàn thành:** AI tự đọc 100 dòng từ ảnh, nghiệm thu chất lượng vision model thực tế, điều chỉnh bút toán production, phân bổ thuế/giảm giá giữa dòng và import bất đồng bộ quy mô lớn. Chỉ được công bố các phần này sau khi có kiểm thử/bằng chứng riêng.


## Modal thêm từng khoản và thanh công cụ gọn

Trang danh sách nay dùng thanh công cụ nhỏ thay vì hiển thị thường trực form **Thêm một khoản chi**. Nhấn **+ Thêm một khoản chi** để mở modal Hotwire/Turbo Frame, gồm tên hàng, thành tiền, số lượng, đơn giá, danh mục, ngày/giờ/địa điểm tùy chọn của dòng. Import CSV được thu vào mục mở rộng khi cần; liên kết xem đề xuất AI vẫn giữ riêng.

Khi thêm thành công, Turbo Streams cập nhật danh sách có phân trang, số lượng, tổng dòng và chênh lệch; đóng modal, hiển thị thông báo mà không tải lại toàn trang. Nếu dòng mới thuộc trang tiếp theo, hệ thống cung cấp liên kết mở đúng trang, không nhồi quá 25 dòng vào bảng hiện tại. Dữ liệu sai giữ modal mở và giữ giá trị đã nhập. Giao dịch đã xác nhận hoặc workspace không được phép không thể thêm dòng. Tổng tiền của giao dịch cha không tự thay đổi.
