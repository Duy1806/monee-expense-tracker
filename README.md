# Monee – Quản lý chi tiêu cá nhân với OCR hóa đơn và AI

Ứng dụng Flutter quản lý chi tiêu cá nhân, **offline-first**: dữ liệu lưu trên thiết bị
(SQLite), nhận dạng hóa đơn bằng OCR chạy ngay trên máy (Google ML Kit), và phân tích
thói quen chi tiêu bằng Gemini khi có Internet.

## Tính năng

| Nhóm | Nội dung |
|---|---|
| Tài khoản | Đăng ký / đăng nhập cục bộ, giữ phiên, đăng xuất. Mật khẩu băm PBKDF2-HMAC-SHA256 + salt riêng. |
| Hồ sơ | Xem hồ sơ, sửa tên, ảnh đại diện (camera/thư viện), đổi mật khẩu. |
| Cách ly dữ liệu | Mỗi tài khoản chỉ thấy giao dịch, ngân sách, kết quả AI của chính mình. |
| Giao dịch | Thêm / xem / sửa / xóa (có xác nhận), tìm kiếm không phân biệt dấu, lọc danh mục và khoảng ngày, sắp xếp, tổng sau lọc. |
| Hóa đơn | Chụp hoặc chọn ảnh → OCR offline → regex trích số tiền, ngày, cửa hàng → người dùng **xác nhận/sửa** rồi mới lưu. Ảnh được lưu bền vững. |
| Tổng quan | Chi tiêu tháng, 7 ngày gần nhất và so với 7 ngày trước, số giao dịch, ngân sách còn lại, danh mục nhiều nhất, biểu đồ donut theo danh mục, biểu đồ cột 7 ngày, giao dịch gần đây. |
| Ngân sách | Đặt ngân sách tháng; cảnh báo "sắp hết" (từ 80%) và "đã vượt". |
| Thống kê | Báo cáo theo tháng bất kỳ, so với tháng trước, trung bình mỗi ngày. |
| AI | Gemini phân tích chi tiêu, gợi ý tiết kiệm và mục tiêu tháng tới. Chỉ gửi số liệu tổng hợp. |
| Giao diện | Material 3, tông xanh lục, Sáng / Tối / Theo hệ thống (được lưu), responsive (thanh dưới / thanh bên). |

## Kiến trúc

```
lib/
  app/            Dựng Provider, MaterialApp, màn lỗi khởi động
  core/           constants, theme, utils (định dạng, parse tiền), validators, security
  data/
    database/     DataStore (SQLite trên mobile, SharedPreferences trên web), migrations
    models/       Expense, Budget, AppUser
    repositories/ Account, Expense, Budget, Settings
  features/       auth, profile, expenses, receipt_scanner, dashboard, budget,
                  statistics, ai, settings, shell   (mỗi nhóm: providers + screens + widgets)
  services/       gemini_service, receipt_parser, receipt_ocr (ML Kit), lưu ảnh hóa đơn/avatar
  shared/widgets/ Thành phần dùng chung
```

- **Quản lý trạng thái:** Provider (`ChangeNotifier`). Các controller dữ liệu được
  `AuthController` gắn với tài khoản hiện tại qua `ChangeNotifierProxyProvider`.
- **Lưu trữ:** giao diện `DataStore` với hai cài đặt: `SqliteDataStore` (Android) và
  `PrefsDataStore` (web, để phát triển/demo). Cả hai chạy chung một bộ test cách ly dữ liệu.
- **Cách ly dữ liệu:** mọi truy vấn giao dịch và ngân sách đều bắt buộc có `user_id`.

## Cơ sở dữ liệu và di trú

Phiên bản 2, các bảng: `users`, `expenses`, `budgets`, `app_settings`.
Nâng cấp từ phiên bản 1 chỉ dùng `ALTER TABLE ... ADD COLUMN`, **không xóa bảng hay dòng nào**.
Giao dịch cũ có `user_id = NULL` (dữ liệu "legacy"). Sau khi đăng nhập, app hỏi người dùng
có nhận các giao dịch này về tài khoản hiện tại hay không. Việc nhận chỉ xảy ra **một lần**.

## Chạy ứng dụng

```powershell
flutter pub get
flutter run
```

### Bật phân tích AI (Gemini)

Khóa API **không nằm trong mã nguồn**. Truyền khi chạy hoặc build:

```powershell
flutter run --dart-define=GEMINI_API_KEY=<khóa-của-bạn>
```

Không có khóa, tab AI hiển thị "chưa được cấu hình" và mọi chức năng khác vẫn dùng bình thường.
Không commit khóa lên GitHub; nếu lỡ lộ khóa, hãy thu hồi ngay trong Google AI Studio.

## Build APK

```powershell
flutter build apk --release --dart-define=GEMINI_API_KEY=<khóa-của-bạn>
```

File kết quả: `build/app/outputs/flutter-apk/app-release.apk`.

Cần có trong `android/`:

1. `AndroidManifest.xml` khai báo `<uses-permission android:name="android.permission.INTERNET"/>`
   (bản debug tự có, bản release thì không).
2. `android/app/proguard-rules.pro` và dòng `proguardFiles(...)` trong khối `release` của
   `android/app/build.gradle.kts`, để R8 không báo thiếu lớp ML Kit cho các ngôn ngữ
   (Trung, Nhật, Hàn, Devanagari) mà app không dùng. Xem `docs/BUILD_AND_RELEASE.md`.

APK hiện ký bằng khóa debug, đủ cho demo. Muốn phát hành cần tạo keystore riêng.

## Kiểm thử

```powershell
flutter analyze
flutter test
```

Bộ test gồm test đơn vị, test repository trên SQLite thật (FFI) và kho web, và widget test.
Đối chiếu từng yêu cầu chức năng (FR-01…FR-14) với test nằm ở `docs/TEST_MATRIX.md`.
Kết quả lần chạy gần nhất ghi trong `docs/TEST_MATRIX.md`.

## Bảo mật và quyền riêng tư

- Mật khẩu băm PBKDF2-HMAC-SHA256 (60.000 vòng lặp), salt ngẫu nhiên theo người dùng,
  thông báo đăng nhập sai không tiết lộ email có tồn tại hay không. Không ghi mật khẩu vào log.
- Dữ liệu nằm trên thiết bị. Ảnh hóa đơn và ảnh đại diện lưu trong thư mục riêng của app.
- AI chỉ nhận số liệu tổng hợp (ngày, danh mục, số tiền). **Không gửi** tên giao dịch,
  họ tên, email, ảnh.
- Kết quả AI hiển thị kèm lời tuyên bố chỉ mang tính tham khảo, không phải tư vấn tài chính.

## Hạn chế đã biết

- Đây là xác thực **cục bộ**: không có đồng bộ đám mây, không khôi phục mật khẩu.
  Quên mật khẩu đồng nghĩa không đăng nhập lại được tài khoản đó trên thiết bị.
- Cơ sở dữ liệu SQLite không mã hóa; bảo vệ dựa trên cơ chế cách ly ứng dụng của Android.
- Khóa Gemini nhúng trong APK có thể bị trích xuất. Phát hành thật cần máy chủ trung gian.
- OCR + regex là phương pháp gợi ý, độ chính xác phụ thuộc chất lượng ảnh và mẫu hóa đơn;
  vì vậy mọi kết quả đều phải được người dùng xác nhận trước khi lưu.
- Trên web: không có OCR, không đính kèm ảnh; dữ liệu lưu bằng SharedPreferences.
- Chưa cấu hình iOS (thư mục `ios/` chưa có trong dự án).