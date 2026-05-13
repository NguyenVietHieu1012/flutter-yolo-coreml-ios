# Guide to integrating YOLO CoreML into Flutter (iOS)

# Summary

This document guides the process from exporting a YOLO model to CoreML, preparing a `.mlpackage`, integrating it into an iOS project (Xcode), and the macOS environment configuration steps required to build and deploy a Flutter app to iOS.

## 1. Export model from Ultralytics

Use the command:

```python
model.export(format="coreml", nms=True)
```

- `nms=True` is for detection-type models.

## 2. Prepare the CoreML file (.mlpackage)

1. Download the model exported from Ultralytics.
2. If the model is a folder, rename the extension to `.mlpackage`.
3. Upload the model to Drive or download it directly to macOS.
4. Unzip if necessary.

## 3. Add the model to Xcode

1. Open Xcode → open the `Runner` project.
2. Drag the `.mlpackage` file from Finder into Runner → select **Finish**.
3. Click the Runner (Target) icon.
4. Go to **Build Phases**:
   - **Compile Sources** → remove the `.mlpackage` model if it is listed here.
   - **Copy Bundle Resources** → add the `.mlpackage` model.

---

## Project structure and important components

### lib/

Contains the main source code of the Flutter application.

### pubspec.yaml

Declares dependencies, assets, SDK constraints. Search packages at: [https://pub.dev/](https://pub.dev/)

### ios/Runner/Info.plist

Configuration for camera permissions, saving images, and CoreML settings.

### iOS Minimum Version

- Xcode → **Build Settings**: iOS Deployment Target ≥ 13.0
- Android Studio → `ios/Podfile`: `platform :ios, '13.0'`

### ios/Runner.xcodeproj & ios/Runner.xcworkspace

Used to open the iOS project in Xcode.

---

## Sample YOLO Flutter project reference

[https://github.com/ultralytics/yolo-flutter-app/tree/main/lib](https://github.com/ultralytics/yolo-flutter-app/tree/main/lib)

Files to reference:

- `yolo_view.dart`
- `yolo_task.dart`
- `yolo_controller.dart`

---

# Setting up the Flutter environment to build iOS (macOS)

This section summarizes the necessary steps on macOS (Apple Silicon / Intel). Perform the steps in order.

## A. Preparation: download the Flutter SDK (Apple Silicon)

1. Visit: [https://docs.flutter.dev/install/manual](https://docs.flutter.dev/install/manual) and download **flutter_macos_arm64** (if using Apple Silicon) or the corresponding macOS version.
2. Extract and move into the user directory:

```bash
# example downloaded file name: flutter_macos_arm64.tar.xz
tar -xvf flutter_macos_arm64.tar.xz
# move the flutter directory to $HOME
mv flutter "$HOME/flutter"
```

3. Add Flutter to PATH:

```bash
echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.zprofile
source ~/.zprofile
```

4. Check:

```bash
flutter --version
flutter doctor
```

## B. Android SDK command-line tools (if you need to build Android or run SDK commands)

Open Android Studio → **Settings** (Preferences) → **Languages & Frameworks** → **Android SDK** → **SDK Tools** tab → tick **Android SDK Command-line Tools (latest)** → Apply → OK.

After installing, run:

```bash
flutter doctor --android-licenses
flutter doctor
```

## C. Install Homebrew, CocoaPods and configure Xcode

1. Install Homebrew (if not already installed):

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Set up brew environment for the shell
echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"
```

2. Install CocoaPods and set up:

```bash
brew install cocoapods
pod setup
```

3. Accept the Xcode license and select the Xcode developer path:

```bash
sudo xcodebuild -license accept
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

4. If you need to run commands related to signing or building, ensure you have opened Xcode at least once to install additional components.

## D. Download required tools and browsers

- Download Google Chrome for macOS (if needed to test WebView or debug web content).
- Download the iOS Simulator (corresponding simulator versions) in Xcode → Preferences → Components. Choose the runtime/simulator version you need (e.g., iOS 16.x/17.x depending on target).
- Here I use iOS simulator 26.2

## 4. Fetch Flutter dependencies

```bash
cd <project_root>
flutter pub get
```

## 5. Build & run the app on iOS

```bash
# build and run on simulator or device
flutter run
# or build ipa
flutter build ipa
```

---

# Actions when changing the deployment device or deploying to a new iOS device

Perform the following steps when changing iPhone or deploying the app to an iOS device that has not been used before:

1. **Connect the iPhone to macOS via cable**
   - On the iPhone select **Trust This Computer** → **Trust**.

2. **Enable Developer Mode on the iPhone**
   - Go to **Settings → Privacy & Security → Developer Mode**
   - Turn **ON** → the iPhone will request a **Restart**.

3. **Install the app with Flutter**
   - Run the command:

```bash
flutter run
```

4. **Trust the Developer App**
   - On the iPhone go to: **Settings → General → VPN & Device Management**
   - Select **Developer App** (Apple ID / Team)
   - Tap **Trust** → **Confirm**.

After completion, the Flutter app can run normally on the iOS device.

---

# Technical notes / Tips

- Always ensure `ios/Podfile` has `platform :ios, '13.0'` (or higher) if the CoreML model requires it.
- If you encounter CocoaPods-related errors: try `pod repo update` and `pod install --repo-update` inside the `ios/` directory.
- If Xcode requests additional toolchains or components, open Xcode and update via Preferences → Components.

---

# References

- Ultralytics YOLO Flutter example: https://github.com/ultralytics/yolo-flutter-app/tree/main/lib
- Flutter docs: https://docs.flutter.dev/
