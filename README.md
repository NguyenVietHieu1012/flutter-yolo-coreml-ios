# Hướng dẫn tích hợp YOLO CoreML vào Flutter (iOS)

## 1. Export model từ Ultralytics

Sử dụng câu lệnh:

```python
model.export(format="coreml", nms=True)
```

* `nms=True` dành cho các model dạng detection.

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

   * **Compile Sources** → xóa model `.mlpackage`.
   * **Copy Bundle Resources** → thêm model `.mlpackage`.

## Cấu trúc thư mục và thành phần quan trọng

### lib/

Chứa mã nguồn chính của ứng dụng Flutter.

### pubspec.yaml

Khai báo dependencies, assets, SDK constraints. Tra cứu package: [https://pub.dev/](https://pub.dev/)

### ios/Runner/Info.plist

Cấu hình quyền camera, lưu ảnh và cấu hình CoreML.

### iOS Minimum Version

* Xcode → **Build Settings**: iOS Deployment Target ≥ 13.0
* Android Studio → `ios/Podfile`: `platform :ios, '13.0'`

### ios/Runner.xcodeproj & ios/Runner.xcworkspace

Dùng để mở dự án iOS trong Xcode.

## Tham khảo dự án mẫu YOLO Flutter

[https://github.com/ultralytics/yolo-flutter-app/tree/main/lib](https://github.com/ultralytics/yolo-flutter-app/tree/main/lib)

Các file cần tham khảo:

* `yolo_view.dart`
* `yolo_task.dart`
* `yolo_controller.dart`

# Cài đặt môi trường Flutter để build iOS

## 1. Cài đặt Flutter SDK

```bash
export PATH="$PATH:/path-to-flutter/bin"
```

## 2. Kiểm tra môi trường Flutter

```bash
flutter doctor
```

## 3. Cài đặt Xcode

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

## 4. Cài đặt CocoaPods

```bash
brew install cocoapods
pod setup
```

## 5. Tải dependencies Flutter

```bash
flutter pub get
```

## 6. Chạy ứng dụng Flutter trên iOS

```bash
flutter run
```

## Thao tác khi đổi thiết bị deploy hoặc triển khai trên thiết bị iOS mới

Thực hiện các bước sau khi đổi iPhone hoặc deploy app trên thiết bị iOS chưa từng sử dụng:

1. **Kết nối iPhone với macOS bằng cáp**

   * Trên iPhone chọn **Trust This Computer** → **Trust**.

2. **Bật Developer Mode trên iPhone**

   * Vào **Settings → Privacy & Security → Developer Mode**
   * Chuyển **ON** → iPhone sẽ yêu cầu **Restart**.

3. **Cài ứng dụng bằng Flutter**

   * Chạy lệnh:

     ```bash
     flutter run
     ```
   * Ứng dụng sẽ được build và cài trực tiếp lên iPhone.

4. **Tin cậy nhà phát triển (Developer App)**

   * Trên iPhone vào:
     **Settings → General → VPN & Device Management**
   * Chọn **Developer App** (Apple ID / Team)
   * Nhấn **Trust** → **Confirm**.

Sau khi hoàn tất, ứng dụng Flutter có thể chạy bình thường trên thiết bị iOS.
