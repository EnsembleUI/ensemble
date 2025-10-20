# Starter Integration Guide for QR Scanner Module

This document describes how the QR scanner module integrates with the Ensemble starter project.

## Quick Start

### Using Enable Script (Recommended)

```bash
cd starter
dart run scripts/modules/enable_qr_code.dart
flutter pub get
flutter run
```

This automatically:
- ✅ Adds `ensemble_qr_scanner` to pubspec.yaml
- ✅ Updates ensemble_modules.dart with imports and registration
- ✅ Adds camera permission to Android manifest
- ✅ Adds camera usage description to iOS Info.plist

### Manual Setup

1. **Update pubspec.yaml:**
```yaml
dependencies:
  ensemble_qr_scanner:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/qr_scanner
```

2. **Update lib/generated/ensemble_modules.dart:**
```dart
// Add import at top
import 'package:ensemble_qr_scanner/qr_code_scanner.dart';

// In init() method, inside useCamera block:
GetIt.I.registerSingleton<EnsembleQRCodeScanner>(
    EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));
```

3. **Add permissions:**

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera permission is required for QR code scanning</string>
```

4. **Run the app:**
```bash
flutter pub get
flutter run
```

## Module Comparison

### ensemble_qr_scanner (Lightweight - New)

**Use when:** You ONLY need QR/Barcode scanning

**Includes:**
- QR Code scanning ✅
- Barcode scanning (Code 128, 39, 93, EAN, UPC) ✅
- Camera controls (flash, flip, pause/resume) ✅

**Dependencies:**
- mobile_scanner: ^6.0.11
- ensemble (core)

**Size:** ~4KB

**Permissions:**
- Camera only

**Enable with:**
```bash
dart run scripts/modules/enable_qr_code.dart
```

### ensemble_camera (Full-Featured)

**Use when:** You need camera features beyond QR scanning

**Includes:**
- Photo/Video capture ✅
- Face detection ✅
- Accelerometer assistance ✅
- GPS/location tracking ✅
- QR Code scanning ✅ (re-exported from qr_scanner)

**Dependencies:**
- camera: ^0.11.0+2
- face_camera: ^0.1.4
- mobile_scanner (via qr_scanner)
- geolocator: ^9.0.2
- sensors_plus: ^7.0.0
- video_player: ^2.6.1
- path_provider: ^2.1.5
- share_plus: ^12.0.0

**Size:** ~400KB+

**Permissions:**
- Camera
- Location (for GPS features)
- Microphone (for video recording)
- Photo library

**Enable with:**
```bash
dart run scripts/modules/enable_camera.dart
```

## Decision Tree

```
Do you need QR/Barcode scanning?
│
├─ Yes → Do you ALSO need photo/video/face detection?
│        │
│        ├─ Yes → Use ensemble_camera
│        │        dart run scripts/modules/enable_camera.dart
│        │
│        └─ No → Use ensemble_qr_scanner (lightweight!)
│                 dart run scripts/modules/enable_qr_code.dart
│
└─ No → Skip both modules
```

## Backward Compatibility

**Existing apps using ensemble_camera for QR scanning:**

✅ No changes needed! The camera module re-exports QR scanner functionality.

Your existing code continues to work:
```dart
import 'package:ensemble_camera/qr_code_scanner.dart';
// Still works! Re-exports from ensemble_qr_scanner
```

**Optional migration to lightweight module:**

If you realize you don't need camera features:

1. Run:
```bash
dart run scripts/modules/enable_qr_code.dart
```

2. Remove camera module from pubspec.yaml (if not needed)

3. Update import (optional):
```dart
// Change from:
import 'package:ensemble_camera/qr_code_scanner.dart';

// To:
import 'package:ensemble_qr_scanner/qr_code_scanner.dart';
```

## Files Modified by Enable Scripts

### enable_qr_code.dart modifies:

1. **starter/pubspec.yaml** - Adds ensemble_qr_scanner dependency
2. **starter/lib/generated/ensemble_modules.dart** - Adds import and registration
3. **starter/android/app/src/main/AndroidManifest.xml** - Adds camera permission
4. **starter/ios/Runner/Info.plist** - Adds camera usage description

### enable_camera.dart modifies:

All of the above PLUS:
5. **starter/web/index.html** - Adds face detection scripts for web support

## Usage in Ensemble Apps

Once enabled, use in your YAML files:

```yaml
View:
  body:
    Column:
      children:
        - QRCodeScanner:
            id: myScanner
            initialCamera: back
            formatsAllowed:
              - qrcode
            onReceived: |
              //@code
              console.log("Scanned: " + event.data.data);
```

No difference in usage whether you use `ensemble_qr_scanner` or `ensemble_camera` - the widget works the same!

## Troubleshooting

### "Package not found" error

Make sure you ran:
```bash
flutter pub get
```

### QR Scanner not showing up

1. Check `lib/generated/ensemble_modules.dart` has the import uncommented
2. Check registration is uncommented in the `init()` method
3. Clean and rebuild:
```bash
flutter clean
flutter pub get
flutter run
```

### Permission denied on iOS

1. Check `ios/Runner/Info.plist` has `NSCameraUsageDescription`
2. Uninstall app from device/simulator and reinstall
3. Check device Settings → Privacy → Camera

### Permission denied on Android

1. Check `android/app/src/main/AndroidManifest.xml` has camera permission
2. For Android 6.0+, ensure runtime permissions are handled (done automatically by mobile_scanner)

## Version Compatibility

| Ensemble Version | QR Scanner Module | Camera Module | Notes |
|------------------|-------------------|---------------|-------|
| < v1.2.13 | N/A | Includes QR | QR built into camera |
| >= v1.2.13 | v0.0.1+ | v0.0.1+ | QR separated, camera re-exports |

## Support

For issues or questions:
- GitHub: https://github.com/EnsembleUI/ensemble/issues
- Documentation: https://docs.ensembleui.com
