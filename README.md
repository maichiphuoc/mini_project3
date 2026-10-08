# SpendLens — OCR Expense Tracker

Ứng dụng Flutter quản lý chi tiêu cá nhân bằng SQLite. Người dùng có thể chụp hoặc chọn ảnh hóa đơn, cắt/xoay ảnh, nhận diện chữ bằng Google ML Kit trên thiết bị, kiểm tra kết quả parser và lưu giao dịch. Giao diện bằng tiếng Việt, đơn vị mặc định VND.

## Tính năng

- Camera sau, khung căn hóa đơn, đèn flash, chạm để lấy nét, chọn ảnh từ thư viện.
- Cắt và xoay ảnh trước khi OCR; có thể bỏ qua bước cắt.
- OCR ML Kit chạy qua native plugin Android/iOS, không gọi API máy chủ.
- Parser pure Dart dùng từ khóa, vị trí và điểm heuristic để tìm cửa hàng, tổng tiền, ngày; giữ văn bản OCR gốc và cảnh báo trường chưa chắc chắn.
- Màn hình xác nhận cho phép sửa mọi trường trước khi lưu.
- SQLite: thêm, xem, sửa, xóa, tìm kiếm, lọc ngày/danh mục, sắp xếp giao dịch.
- Biểu đồ vòng và cột vẽ bằng `CustomPainter`, có animation và thao tác chạm.

## Công nghệ và kiến trúc

Flutter 3.22.1 / Dart 3.4.1; `camera`, `image_picker`, `image_cropper`, `google_mlkit_text_recognition`, `sqflite`, `flutter_riverpod`, `path_provider`, `intl`.

```text
lib/
  core/       Expense, danh mục, định dạng VND/ngày
  data/       ExpenseRepository và SQLite schema
  services/   ML Kit OCR, parser heuristic, lưu ảnh và thumbnail
  state/      Riverpod providers
  ui/         Dashboard, history, scanner, review, detail, analytics, charts
```

Luồng ảnh: **Camera / thư viện → xem/cắt/xoay → ML Kit OCR → parser → xác nhận → SQLite**. Ảnh hóa đơn được sao chép vào thư mục tài liệu riêng của ứng dụng, kèm thumbnail 240px. Không có tài khoản, backend, Firebase, cloud OCR hoặc tracking.

## Cài đặt và chạy

Yêu cầu Flutter 3.22.1 trở lên trong dòng 3.x có Dart 3.4+, Android SDK platform 35, JDK 17/21, thiết bị Android API 23+ hoặc môi trường iOS 15.5+. Các dependency được khóa trong `pubspec.lock` để tái lập build.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --release
```

Android: `CAMERA` được khai báo trong manifest; `UCropActivity` dùng cho màn hình cắt ảnh. `compileSdk`/`targetSdk` là 35 và `minSdk` là 23. iOS có mô tả quyền camera/thư viện và Podfile đặt deployment target 15.5. Plugin OCR chỉ hỗ trợ Android/iOS, vì vậy không chạy luồng quét trên Flutter Web/Windows.

APK release hiện dùng **debug signing** của mẫu Flutter để thử nghiệm cục bộ. Trước khi phát hành công khai, cấu hình keystore release riêng và thay signing config.

## Parser và dữ liệu

`ReceiptParser` chuẩn hóa dòng văn bản, tìm số tiền VND theo nhiều định dạng, loại dòng điện thoại/mã số thuế, cộng/trừ điểm theo từ khóa như `TỔNG THANH TOÁN`, `TOTAL`, `TIỀN THỪA`, `GIẢM GIÁ`. Ngày được kiểm tra bằng `DateTime` để loại ngày không hợp lệ; năm hai chữ số `70–99` quy về 19xx, `00–69` quy về 20xx. Tên cửa hàng được chọn trong phần đầu hóa đơn sau khi loại tiêu đề, số điện thoại, địa chỉ và ngày. Category chỉ là gợi ý từ khóa; trường không chắc chắn cần người dùng xác nhận.

SQLite lưu `amount` dưới dạng số nguyên VND, ngày dưới dạng Unix milliseconds, danh mục là key cố định, cùng đường dẫn ảnh/thumbnail và OCR text. Chỉ có một bảng `expenses` và index theo ngày. Dữ liệu chỉ nằm trong local storage của ứng dụng.

## Biểu đồ

`DonutPainter` vẽ phân bố danh mục trong kỳ; `BarChartPainter` vẽ tổng từng ngày trong tuần hiện tại. Dữ liệu được tính từ danh sách giao dịch SQLite qua Riverpod và cập nhật sau thêm/sửa/xóa. Chạm vào biểu đồ để xem giá trị.

## Kiểm thử

`test/receipt_parser_test.dart` có 18 ca kiểm thử: ưu tiên tổng tiền trước tiền khách đưa/tiền thừa, các định dạng VND, ngày hợp lệ/sai, năm nhuận, mã số thuế, số điện thoại, danh mục và OCR rỗng. `test/expense_repository_test.dart` có 4 ca dùng SQLite FFI thật để kiểm tra CRUD, tính bền dữ liệu, thứ tự ngày và ràng buộc số tiền. `flutter test` đạt 22/22; `flutter analyze` không có issue. APK release đã được cài và chạy trên Android emulator API 35. Camera, crop, chọn ảnh, OCR ngoại tuyến với [ảnh hóa đơn tổng hợp](test/fixtures/receipt_sample.png), SQLite CRUD, dữ liệu qua khởi động lại và biểu đồ đã được kiểm tra. Xem [kịch bản demo](docs/DEMO.md).

## Ảnh chụp ứng dụng

Ảnh thật từ APK chạy trên Android emulator API 35: [Dashboard](docs/screenshots/dashboard.png), [Camera](docs/screenshots/scanner.png), [OCR Review](docs/screenshots/review.png), [Analytics](docs/screenshots/analytics.png), [Lịch sử](docs/screenshots/history.png), [Chi tiết](docs/screenshots/detail.png). Ảnh Review dùng fixture tổng hợp, không chứa hóa đơn cá nhân.

## Giới hạn hiện tại

- ML Kit Latin có thể đọc kém ảnh mờ, chữ nhỏ hoặc hóa đơn nhiều cột. Người dùng luôn có thể sửa trong màn hình xác nhận.
- Điểm confidence là heuristic do ứng dụng tự tính, không phải xác suất ML Kit.
- Chưa đo độ chính xác OCR trên tập hóa đơn thật hoặc thời gian xử lý đại diện trên điện thoại vật lý. Chưa kiểm thử iOS và đầy đủ tình huống quyền camera bị từ chối/ảnh mờ.
- Chưa có video demo. Ảnh chụp hiện có là từ Android emulator, không phải điện thoại vật lý.

## Nộp bài

- APK demo: [tải SpendLens-v1.0.0-demo.apk](https://github.com/maichiphuoc/mini_project3/releases/download/v1.0.0-demo/SpendLens-v1.0.0-demo.apk) (91,7 MB) trên điện thoại Android rồi mở tệp để cài. APK nằm trong GitHub Releases, không nằm trong Git source. Bản này ký bằng debug key cho demo nội bộ. Có thể build lại bằng `flutter build apk --release` để tạo `build/app/outputs/flutter-apk/app-release.apk`.
- Demo: quay theo [docs/DEMO.md](docs/DEMO.md) trên thiết bị Android vật lý nếu bài nộp yêu cầu video.
- Báo cáo: [docs/report.pdf](docs/report.pdf), bốn trang, có ảnh chụp thực từ emulator và kết quả kiểm thử.
- GitHub: [maichiphuoc/mini_project3](https://github.com/maichiphuoc/mini_project3).
