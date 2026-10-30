# Rails 8 AI Expense & Sales Manager

Ứng dụng Rails 8 và PostgreSQL quản lý thu/chi, kiểm tra chứng từ bởi người dùng, lưu lịch sử ảnh và xuất báo cáo tài chính.

English: [README.md](README.md)

## Chức năng

- Đăng nhập theo cơ chế Rails 8, workspace riêng theo tài khoản.
- Nhập khoản thu/chi thủ công, không bắt buộc phải có ảnh hoặc kết quả AI.
- Ngày và số tiền giao dịch do người dùng xác nhận; không tự lấy từ EXIF hoặc thời điểm tải lên.
- Lưu mọi phiên bản ảnh chứng từ bằng Active Storage private, SHA256 và metadata.
- Lưu từng lượt AI nhận diện và từng trường gợi ý để kiểm tra độc lập, không tự động ghi tài chính.
- Phân biệt trạng thái đọc được, đọc một phần, không đọc được và lỗi xử lý.
- Chỉ tổng hợp giao dịch đã xác nhận vào biểu đồ tháng và CSV.
- PostgreSQL khóa giao dịch đã chốt và bảo toàn lịch sử audit/bằng chứng.

## Cài đặt và chạy

Yêu cầu Ruby 3.2+, PostgreSQL 16+, libvips 42 và Bundler.

1. Chạy bundle install.
2. Chạy bin/rails db:prepare.
3. Chạy bin/rails server.
4. Truy cập http://localhost:3000/registration/new để tạo tài khoản và workspace cá nhân.
5. Đăng nhập tại /session/new để quản lý thu/chi.

Mặc định tính năng đăng ký chỉ bật ở môi trường development/test. Trên production cần chủ động cấu hình ENABLE_SIGNUP=true.

## Kiểm thử

Chạy bin/rails test và ruby tests/test_input_policy.rb. GitHub Actions chạy lại cả hai bộ kiểm thử với PostgreSQL.

## An toàn và bằng chứng

Người dùng chỉ được xem dữ liệu và ảnh thuộc workspace đã phân quyền. Mỗi ảnh là một phiên bản độc lập; kết quả AI và lịch sử audit được lưu giữ. Có thể thêm ảnh sau khi chốt mà không tự thay đổi giao dịch đã xác nhận.

Ứng dụng không tự suy ngày hoặc tiền bằng OCR regex, heuristic hoặc phép tính ngược từ ảnh. Trường không chắc chắn phải để trống, để người dùng nhập hoặc kiểm tra. Báo cáo chỉ tính dữ liệu được xác nhận.

## Trạng thái triển khai

Đây là nền tảng Rails có thể chạy, chưa phải phần mềm kế toán production. Chưa bật adapter llama.cpp/GGUF thực tế do model nghiên cứu chưa qua quality gate chữ viết tay khó đọc. Module tồn kho/bán hàng hoàn chỉnh, quy trình điều chỉnh giao dịch, xuất PDF, chia sẻ workspace theo vai trò và hardening production là các bước tiếp theo.


## Xem thử qua Cloudflare Quick Tunnel

Cờ chạy chỉ dành cho môi trường development sẽ cho phép hostname `*.trycloudflare.com`, tắt trang debug chi tiết của Rails khi truy cập từ tunnel và khóa chức năng tự đăng ký công khai.

```bash
FINANCE_DEMO_PREVIEW=1 bin/rails server --binding 127.0.0.1 --port 3078
cloudflared tunnel --no-autoupdate --url http://127.0.0.1:3078
```

Chỉ sử dụng tài khoản demo riêng và dữ liệu tổng hợp giả lập. Link Quick Tunnel có thể đổi và không thay thế cơ chế xác thực. Triển khai production phải có bảo vệ host, phân quyền và hạ tầng riêng. Adapter GGUF inference chưa được bật trong bản demo này.


## Tổng quan, báo cáo và đa ngôn ngữ

- Dashboard tương thích máy tính và thiết bị di động, có bốn chỉ số tài chính, tìm kiếm, bộ lọc trạng thái/loại giao dịch và phân trang.
- Báo cáo có so sánh tháng trước, xu hướng sáu tháng, tỷ trọng danh mục chi, phát sinh theo ngày, danh sách giao dịch đã xác nhận và xuất CSV.
- Chuyển ngôn ngữ tiếng Anh / tiếng Việt bằng Rails I18n và signed cookie. Hai bộ dịch được lưu riêng; dữ liệu tài chính và CSV không đổi.
- Trang hướng dẫn từng bước về nhập thủ công, lưu phiên bản ảnh, kiểm duyệt AI và xác nhận giao dịch.

**Chi tiết:** [Giao diện và báo cáo thu chi (Tiếng Việt)](docs/UX_REPORTING.vi.md).

Bản demo Cloudflare hiện tại chỉ sử dụng dữ liệu giả lập. AI GGUF chưa được bật; ứng dụng chưa tuyên bố đạt chuẩn kế toán production.
