# Sắp xếp danh sách khoản chi tiết

Trang Danh sách khoản chi tiết (/finance/transactions/:id/line_items) đã hỗ trợ sắp xếp **toàn bộ khoản chi tiết** của giao dịch **trước khi phân trang** 25 dòng/trang. Đây chỉ là cách sắp xếp khi xem.

## Các trường có thể sắp xếp

| Trường | Quy tắc |
|---|---|
| Thứ tự gốc | Theo vị trí position đã lưu, mặc định tăng dần |
| Tên khoản | Theo chữ cái, không phân biệt hoa/thường |
| Số tiền | Theo số tiền thực tế |
| Giờ phát sinh | Theo thời gian; khoản chưa nhập giờ luôn ở cuối |
| Địa điểm | Theo chữ cái, không phân biệt hoa/thường; khoản không có địa điểm ở cuối |

Các trường đều có hai chiều Tăng dần / Giảm dần. Trên desktop, bấm tiêu đề cột để đổi chiều; mũi tên và thuộc tính aria-sort thể hiện trạng thái. Đã bỏ khối chọn Sắp xếp theo / Thứ tự. Trên desktop rộng vẫn bấm tiêu đề cột để sắp xếp; bấm cột # để chọn thứ tự gốc mặc định.

Cột Ngày không có lựa chọn sắp xếp vì mọi khoản dùng chung ngày của giao dịch. Số thứ tự hiển thị trên khoản (ví dụ #9) luôn là vị trí gốc trong hóa đơn, kể cả khi danh sách đang xem theo tiền hoặc tên.

## An toàn và bảo toàn trạng thái

- Server chỉ chấp nhận cột và chiều nằm trong allowlist cố định; giá trị khác bị từ chối HTTP 400, không chèn nguyên SQL từ URL.
- Nếu giá trị bằng nhau, xếp tiếp theo position và ID để phân trang ổn định. Giờ hoặc địa điểm rỗng được đưa về cuối ở cả hai chiều.
- Phân trang theo thứ tự đã chọn; khi đổi trường, mặc định quay về trang 1. Link trang tiếp theo vẫn giữ sắp xếp.
- Thêm/sửa khoản trong bản nháp qua modal vẫn giữ lựa chọn. Nếu có thể thay đổi vị trí theo tiêu chí đang chọn, danh sách được render lại. Khoản mới ở trang khác có link đến đúng trang.
- Xóa, import CSV và điều hướng thường đều giữ lại lựa chọn sắp xếp. Giao dịch đã xác nhận chỉ cho phép đổi cách xem; muốn sửa phải sử dụng quy trình điều chỉnh có lịch sử kiểm toán.
- **Không sửa position đã lưu**, tiền, Tags, ngày giao dịch, chứng từ hoặc lịch sử; không có migration.

## Kiểm thử

Rails integration tests kiểm tra các cột, hai chiều, giờ/địa điểm rỗng, dữ liệu vượt 25 khoản, tham số không hợp lệ, modal thêm/sửa, xóa và khả năng xem giao dịch đã khóa. Chromium có đăng nhập kiểm tra transaction #14 với 100 khoản ở màn hình 375, 414, 768, 1024, 1366 và 1472px, bao gồm sắp xếp tiền giảm dần, tên tăng dần, phân trang và responsive.

## Ngày giao dịch dùng chung ở đầu trang

Thông tin **Ngày giao dịch (dùng chung)** nay chỉ hiển thị một lần trong dải thông tin gọn ngay dưới tiêu đề trang, phía trên các chỉ số tổng hợp. Mỗi khoản chi tiết đều dùng ngày của giao dịch cha, vì vậy đã bỏ cột Ngày lặp lại trong bảng desktop và các thẻ trên mobile. Bảng còn sáu cột: thứ tự gốc, tên khoản, số tiền, giờ tùy chọn, địa điểm tùy chọn và thao tác.

Không có ngày riêng của từng khoản, không sửa dữ liệu ngày. Các chức năng sắp xếp, phân trang 25 dòng, modal chỉnh sửa và thứ tự gốc đều giữ nguyên.
