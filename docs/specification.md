
# Mini Project 3 — Expense Tracker

## 1. Mục tiêu

Xây dựng ứng dụng Flutter quản lý chi tiêu cá nhân,
hỗ trợ nhập giao dịch thủ công, nhận dạng hóa đơn
bằng OCR, lưu dữ liệu offline và phân tích chi tiêu bằng AI.

## 2. Chức năng

FR-01: Hiển thị tổng chi tiêu và ngân sách còn lại.

FR-02: Thêm giao dịch với tên, số tiền, danh mục và ngày.

FR-03: Kiểm tra dữ liệu đầu vào trước khi lưu.

FR-04: Hiển thị danh sách giao dịch theo ngày giảm dần.

FR-05: Xóa giao dịch và cập nhật lại thống kê.

FR-06: Lưu dữ liệu cục bộ, sử dụng SQLite trên mobile.

FR-07: Chọn hoặc chụp ảnh hóa đơn.

FR-08: OCR on-device nhận dạng văn bản offline.

FR-09: Regex trích xuất số tiền, ngày và người nhận/
cửa hàng từ văn bản OCR.

FR-10: Cho phép người dùng xác nhận hoặc sửa dữ liệu OCR
trước khi lưu giao dịch.

FR-11: Hiển thị biểu đồ donut theo danh mục.

FR-12: Hiển thị biểu đồ chi tiêu trong 7 ngày gần nhất.

FR-13: Tích hợp Gemini để phân tích thói quen chi tiêu,
đề xuất ngân sách và mục tiêu tiết kiệm khi có Internet.

FR-14: Ứng dụng vẫn xem, thêm và quản lý giao dịch
khi không có Internet.

## 3. Quy tắc kiểm tra dữ liệu

- Tên giao dịch không được để trống.
- Số tiền phải là số hữu hạn và lớn hơn 0.
- Danh mục phải thuộc danh sách được hỗ trợ.
- Ngày giao dịch phải hợp lệ.
- Dữ liệu OCR chỉ là dữ liệu gợi ý, không tự động lưu
  nếu người dùng chưa xác nhận.
- Không tạo giao dịch khi dữ liệu không hợp lệ.

## 4. Quy tắc thống kê

- Tổng chi tiêu bằng tổng số tiền của các giao dịch.
- Chi tiêu hôm nay chỉ tính giao dịch trong ngày hiện tại.
- Ngân sách còn lại bằng ngân sách trừ tổng chi tiêu.
- Biểu đồ danh mục được tính từ dữ liệu giao dịch.
- Biểu đồ tuần gồm 7 ngày gần nhất, kể cả ngày không chi.
- Xóa hoặc thêm giao dịch phải cập nhật thống kê.

## 5. Kiến trúc dự kiến

- Presentation: giao diện Flutter.
- Model: Expense, Category và dữ liệu OCR.
- Repository: giao diện truy cập dữ liệu.
- Local storage: SQLite trên mobile, adapter phù hợp
  trên Web để phát triển và demo.
- OCR: nhận dạng văn bản trên thiết bị.
- Parser: Regex và quy tắc trích xuất dữ liệu.
- AI service: gọi Gemini khi có kết nối mạng.

## 6. Tiêu chí nghiệm thu

Mỗi yêu cầu FR phải có ít nhất một test case tương ứng.
Không được đánh dấu hoàn thành nếu chưa kiểm thử.

Ứng dụng phải phân biệt dữ liệu mẫu với dữ liệu thật.
Các lỗi OCR, dữ liệu không hợp lệ và lỗi mạng phải
được xử lý rõ ràng, không làm mất giao dịch đã lưu.
