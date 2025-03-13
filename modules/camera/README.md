# Ensemble Camera Module

Ensemble Camera is a Flutter package that extends the capabilities of the [Ensemble](https://github.com/EnsembleUI/ensemble) framework by providing a comprehensive camera module. It simplifies the integration of camera functionalities into your app with features such as photo and video capture, QR code scanning, and face detection. With customizable options and built-in sensor support, Ensemble Camera allows you to create engaging, camera-driven experiences quickly.

## Features

- **Photo & Video Capture**
  - Capture photos and videos using both a default camera interface and a bespoke, customizable camera view.
  - Supports front/back camera selection, flash control, and camera rotation.
  - Options for gallery image picking and auto-capture intervals.

- **QR Code Scanning**
  - Integrated QR code scanner using the `qr_code_scanner` package.
  - Customizable overlay, scan area, and scanning actions.
  - Built-in methods to flip the camera, toggle flash, pause, and resume scanning.

- **Face Detection**
  - Face detection support powered by the `face_camera` package.
  - Real-time face detection with auto-capture capabilities.
  - Customizable UI controls and messages to guide users during face capture.

- **Sensor Integration**
  - Utilizes device sensors (accelerometer and geolocation) to assist with camera orientation and to improve capture conditions.

- **Seamless Ensemble Integration**
  - Leverages Ensemble actions and data contexts for streamlined binding and event handling.
  - Easy to configure via provided controllers and setter methods.

## Getting Started

### Prerequisites

- **Flutter SDK:** >= 3.24.0
- **Dart SDK:** >= 3.5.0

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

Make sure to configure the necessary permissions for camera, microphone, and location access in your project for Android and iOS.

## Usage

Below are some basic examples to help you get started:

### Photo & Video Capture

```dart
import 'package:ensemble_camera/ensemble_camera.dart';

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
import 'package:ensemble_camera/ensemble_camera.dart';

// Example: Instantiating the QR code scanner widget
final qrScannerWidget = EnsembleQRCodeScannerImpl.build(myQRCodeScannerController);
```

### Face Detection

```dart
import 'package:ensemble_camera/ensemble_camera.dart';

// Example: Using the Face Detection Camera widget
FaceDetectionCamera(
  onCapture: (path) {
    // Process the captured face image path
  },
  onError: (error) {
    // Handle any errors during face detection
  },
);
```

## Usage with Ensemble

Ensemble Camera can be easily integrated with the Ensemble framework to create dynamic, camera-driven experiences. Below is an example of how to use Ensemble actions to open the camera with specific options and display the captured image in a dialog:

```yaml
openCamera:
    id: cameraWithOptions
    options:
        initialCamera: front
        faceDetection:
        enabled: true
        autoCapture: false
        message: "Align your face in the circle"
        messageStyle:
            color: "#FF0000"
            fontSize: 20
    onCapture:
        showDialog:
        body:
            Image:
            source: ${cameraWithOptions.files[0].path}
```

## Contributing

Contributions are welcome! If you have ideas for improvements or find any issues, please fork the repository and submit a pull request. For major changes, it’s recommended to open an issue first to discuss your proposed changes.
