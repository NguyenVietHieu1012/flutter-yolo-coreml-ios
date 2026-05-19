# Hướng dẫn tích hợp YOLO CoreML vào Flutter (iOS)

# Tóm tắt

Tài liệu này hướng dẫn từ việc export model YOLO sang CoreML, chuẩn bị `.mlpackage`, tích hợp vào project iOS (Xcode) và các bước cấu hình môi trường macOS để build và deploy ứng dụng Flutter lên iOS.

## 1. Export model từ Ultralytics

Sử dụng câu lệnh:

```python
model.export(format="coreml", nms=True)
```

- `nms=True` dành cho các model dạng detection.

## 2. Chuẩn bị file CoreML (.mlpackage)

1. Tải model xuất ra từ Ultralytics.
2. Nếu model là thư mục, đổi đuôi thành `.mlpackage`.
3. Đưa model lên Drive hoặc tải trực tiếp về macOS.
4. Giải nén nếu cần.

## 3. Thêm model vào Xcode

1. Mở Xcode → mở project `Runner`.
2. Kéo file `.mlpackage` từ Finder vào Runner → chọn **Finish**.
3. Nhấn vào biểu tượng Runner (Target).
4. Vào **Build Phases**:
   - **Compile Sources** → xóa model `.mlpackage` nếu nó được liệt kê ở đây.
   - **Copy Bundle Resources** → thêm model `.mlpackage`.

---

## Cấu trúc thư mục và thành phần quan trọng

### lib/

Chứa mã nguồn chính của ứng dụng Flutter.

### pubspec.yaml

Khai báo dependencies, assets, SDK constraints. Tra cứu package: https://pub.dev/

### ios/Runner/Info.plist

Cấu hình quyền camera, lưu ảnh và cấu hình CoreML.

### iOS Minimum Version

- Xcode → **Build Settings**: iOS Deployment Target ≥ 13.0
- Android Studio → `ios/Podfile`: `platform :ios, '13.0'`

### ios/Runner.xcodeproj & ios/Runner.xcworkspace

Dùng để mở dự án iOS trong Xcode.

---

## Tham khảo dự án mẫu YOLO Flutter

https://github.com/ultralytics/yolo-flutter-app/tree/main/lib

Các file cần tham khảo:

- `yolo_view.dart`
- `yolo_task.dart`
- `yolo_controller.dart`

---

# Cài đặt môi trường Flutter để build iOS (macOS)

Phần này tóm tắt các bước cần thiết trên macOS (Apple Silicon / Intel). Thực hiện tuần tự các bước sau.

## A. Chuẩn bị: tải Flutter SDK (Apple Silicon)

1. Truy cập: https://docs.flutter.dev/install/manual và tải **flutter_macos_arm64** (nếu dùng máy Apple Silicon) hoặc phiên bản macOS tương ứng.
2. Giải nén và di chuyển vào thư mục người dùng:

```bash
# ví dụ file tải về có tên flutter_macos_arm64.tar.xz
tar -xvf flutter_macos_arm64.tar.xz
# di chuyển thư mục flutter vào $HOME
mv flutter "$HOME/flutter"
```

3. Thêm Flutter vào PATH :

```bash
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile
```

4. Kiểm tra:

```bash
flutter --version
flutter doctor
```

## B. Android SDK command-line tools (nếu cần build Android hoặc chạy các lệnh SDK)

Mở Android Studio → **Settings** (Preferences) → **Languages & Frameworks** → **Android SDK** → tab **SDK Tools** → tick **Android SDK Command-line Tools (latest)** → Apply → OK.

Sau khi cài đặt, chạy:

```bash
flutter doctor --android-licenses
flutter doctor
```

## C. Cài Homebrew, CocoaPods và cấu hình Xcode

1. Cài Homebrew (nếu chưa có):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Thiết lập môi trường brew cho shell
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

2. Cài CocoaPods và thiết lập:

```bash
brew install cocoapods
pod setup
```

3. Chấp nhận license Xcode và chọn Xcode developer path:

```bash
sudo xcodebuild -license accept
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

4. Nếu cần chạy lệnh liên quan tới signing hoặc building, đảm bảo bạn đã mở Xcode ít nhất một lần để cài thêm components.

## D. Tải công cụ và trình duyệt cần thiết

- Tải Google Chrome cho macOS (nếu cần để test WebView hoặc debug web content).
- Tải iOS Simulator (phiên bản simulator tương ứng) trong Xcode → Preferences → Components. Chọn phiên bản runtime/simulator bạn cần (ví dụ iOS 16.x/17.x tùy target).
- Ở đây tôi dùng IOS simulator 26.2

## 4. Tải dependencies Flutter

```bash
cd <project_root>
flutter pub get
```

## 5. Build & chạy ứng dụng trên iOS

```bash
# build và chạy trên simulator hoặc thiết bị
flutter run
# hoặc build ipa
flutter build ipa
```

---

# Thao tác khi đổi thiết bị deploy hoặc triển khai trên thiết bị iOS mới

Thực hiện các bước sau khi đổi iPhone hoặc deploy app trên thiết bị iOS chưa từng sử dụng:

1. **Kết nối iPhone với macOS bằng cáp**
   - Trên iPhone chọn **Trust This Computer** → **Trust**.

2. **Bật Developer Mode trên iPhone**
   - Vào **Settings → Privacy & Security → Developer Mode**
   - Chuyển **ON** → iPhone sẽ yêu cầu **Restart**.

3. **Cài ứng dụng bằng Flutter**
   - Chạy lệnh:

```bash
flutter run
```

4. **Tin cậy nhà phát triển (Developer App)**
   - Trên iPhone vào: **Settings → General → VPN & Device Management**
   - Chọn **Developer App** (Apple ID / Team)
   - Nhấn **Trust** → **Confirm**.

Sau khi hoàn tất, ứng dụng Flutter có thể chạy bình thường trên thiết bị iOS.

---

# Ghi chú kỹ thuật / Tips

- Luôn đảm bảo `ios/Podfile` có `platform :ios, '13.0'` (hoặc cao hơn) nếu model CoreML yêu cầu.
- Nếu gặp lỗi liên quan tới CocoaPods: thử `pod repo update` và `pod install --repo-update` trong thư mục `ios/`.
- Nếu Xcode yêu cầu thêm toolchains hoặc components, mở Xcode và cập nhật qua Preferences → Components.

---

# Tham khảo

- Ultralytics YOLO Flutter example: https://github.com/ultralytics/yolo-flutter-app/tree/main/lib
- Flutter docs: https://docs.flutter.dev/
