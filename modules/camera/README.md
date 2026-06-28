# Ensemble Camera Module

Ensemble Camera is a Flutter package that extends the capabilities of the [Ensemble](https://github.com/EnsembleUI/ensemble) framework by providing a comprehensive camera module. It simplifies the integration of camera functionalities into your app with features such as photo and video capture, and QR code scanning.

> [!IMPORTANT]
> **Face Detection has been moved!**
> Real-time face detection is now provided by the standalone `ensemble_face_camera` module. Please see `ensemble_face_camera` for details.

## Features

- **Photo & Video Capture**
  - Capture photos and videos using both a default camera interface and a bespoke, customizable camera view.
  - Supports front/back camera selection, flash control, and camera rotation.
  - Options for gallery image picking and auto-capture intervals.

- **Sensor Integration**
  - Utilizes device sensors (accelerometer and geolocation) to assist with camera orientation and to improve capture conditions.

- **Seamless Ensemble Integration**
  - Leverages Ensemble actions and data contexts for streamlined binding and event handling.
  - Easy to configure via provided controllers and setter methods.

## Getting Started

### Prerequisites

- **Flutter SDK:** >= 3.24.0
- **Dart SDK:** >= 3.5.0

### Enable from Starter (recommended)

From the `starter` app, run the module enable script to add the dependency,
register `CameraManagerImpl`, set `useCamera` in `lib/generated/ensemble_modules.dart`,
and apply platform permissions:

```bash
cd starter
npm run hasCamera
flutter pub get
```

For specific platforms (for example Android, iOS, and web):

```bash
dart scripts/modules/enable_camera.dart platform=android,ios,web
```

On web, the script also adds the required script tag for
`assets/packages/ensemble_camera/web/image_worker.js` in `web/index.html`.

### Installation

Add the following dependency to your `pubspec.yaml`:

```yaml
dependencies:
  ensemble_camera:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main # or a specific version
      path: modules/camera
```

Then run:

```bash
flutter pub get
```

### Permissions

When enabled via the starter script, the following are added automatically:

**Android** (`AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** (`Info.plist` usage descriptions):

- `NSCameraUsageDescription`
- `NSPhotoLibraryUsageDescription`
- `NSMicrophoneUsageDescription`

For manual setup, configure camera, microphone, photo library, and location
access in your host app as required by your capture options.

## Usage

Below are some basic examples to help you get started:

### Photo & Video Capture

```dart
import 'package:ensemble/framework/action.dart';
import 'package:ensemble_camera/camera_manager.dart';

// Example: Using the default camera for photo capture
void openDefaultCamera(BuildContext context, ScopeManager scopeManager) {
  ShowCameraAction cameraAction = ShowCameraAction(
    options: {
      'mode': 'photo',
      'initialCamera': 'back',
      'allowFlashControl': true,
      // Additional options can be configured here
    },
    onComplete: () {
      // Handle capture completion
    },
  );
  CameraManagerImpl().openCamera(context, cameraAction, scopeManager);
}
```

### QR Code Scanner

```dart
import 'package:ensemble_camera/qr_code_scanner.dart';

// Example: Instantiating the QR code scanner widget
final qrScannerWidget = EnsembleQRCodeScannerImpl.build(myQRCodeScannerController);
```

## Usage with Ensemble

Ensemble Camera can be easily integrated with the Ensemble framework to create dynamic, camera-driven experiences. Below is an example of how to use Ensemble actions to open the camera with specific options and display the captured image in a dialog:

```yaml
openCamera:
  id: cameraWithOptions
  options:
    initialCamera: back
    allowFlashControl: true
  onCapture:
    showDialog:
    body:
      Image:
      source: ${cameraWithOptions.files[0].path}
```

<a name="migration"></a>

## Migration from Face Detection

If you were previously using face detection within this module, please follow these steps:

1. Add `ensemble_face_camera` to your `pubspec.yaml`.
2. Update your YAML actions from `openCamera` with `faceDetection: enabled: true` to `openFaceCamera`.
3. Import `package:ensemble_face_camera/ensemble_face_camera.dart` if using Dart.

> [!NOTE]
> Using `faceDetection: enabled: true` within `openCamera` will now print a warning in the console and fall back to the standard camera interface.

## Contributing

Contributions are welcome! If you have ideas for improvements or find any issues, please fork the repository and submit a pull request. For major changes, it’s recommended to open an issue first to discuss your proposed changes.
