# Ensemble Face Camera Module

The `ensemble_face_camera` module provides face detection capabilities to the Ensemble framework. It is a standalone module extracted from the original `ensemble_camera` package.

## Features

- Real-time face detection on both Mobile and Web.
- Customizable detection parameters (threshold, yaw, tilt, etc.).
- Integration with Ensemble Action system via `openFaceCamera`.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  ensemble_face_camera:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/face_camera
```

### Action Registration

To use the `openFaceCamera` action, you must register it in your Ensemble application (usually in `lib/generated/ensemble_modules.dart` or a dedicated setup file):

```dart
import 'package:ensemble_face_camera/ensemble_face_camera.dart';

// ... inside your initialization logic

GetIt.I.registerSingleton<FaceCameraManager>(FaceCameraManagerImpl());
```

## Usage

### YAML Action

The `openFaceCamera` action consolidates all configuration into the `options` map. While top-level properties (like `message`) are still supported for backward compatibility, it is recommended to place them inside `options`.

```yaml
onTap:
  openFaceCamera:
    id: myFaceCamera
    options:
      initialCamera: front       # front (default) or back
      performanceMode: fast      # fast (default) or accurate
      imageResolution: high      # low, medium, high, veryHigh, ultraHigh, max
      defaultFlashMode: off      # off (default), auto, always
      orientation: portraitUp    # portraitUp (default), portraitDown, landscapeLeft, landscapeRight
      
      message: "Align your face" # Custom message to display
      messageStyle:              # Custom text style for the message
        color: 0xFFFFFFFF
        fontSize: 18
      
      indicatorShape: circle     # circle (default) or square
      showStatusMessage: true    # Show/hide the detection status message
      
      showControls: true         # Show/hide all camera controls
      showCaptureControl: true   # Show/hide the capture button
      showFlashControl: true     # Show/hide the flash toggle
      showCameraLensControl: true # Show/hide the camera switch button
      
      autoCapture: false         # Automatically capture when face is aligned
      autoDisableCaptureControl: false # Disable capture button until face is detected

      accuracyConfig:            # Fine-tune detection accuracy
        threshold: 0.6           # Detection threshold (0.0 to 1.0)
        yaw: 15                  # Maximum allowed face rotation (horizontal)
        tilt: 15                 # Maximum allowed face tilt (vertical)
        minFaceSize: 0.15        # Minimum face size relative to frame
        
    onCapture: |
      print('Face captured: ' + event.data.files[0].path);
    onError: |
      print('Error: ' + event.error);
```

### Dart Widget

You can also use the `FaceDetectionCamera` widget directly in your Dart code:

```dart
import 'package:ensemble_face_camera/face_detection_camera.dart';

// ...
FaceDetectionCamera(
  onCapture: (file) => print('Captured: ${file?.path}'),
  onError: (error) => print('Error: $error'),
)
```

## Migration from `ensemble_camera`

If you were previously using `openCamera` with `faceDetection: enabled: true`, follow these steps:

1. Add `ensemble_face_camera` to your `pubspec.yaml`.
2. Replace `openCamera` with `openFaceCamera` in your YAML.
3. Remove `faceDetection: enabled: true` from the options as it's now implicit.
4. Call `GetIt.I.registerSingleton<FaceCameraManager>(FaceCameraManagerImpl());` in your app initialization.
