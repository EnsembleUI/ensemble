# Ensemble QR Scanner

Lightweight QR Code and Barcode scanner module for Ensemble Framework.

## Quick Setup

### Using Enable Script (Recommended)
```bash
cd starter
dart run scripts/modules/enable_qr_code.dart
flutter pub get
flutter run
```

### Manual Installation

1. **Add dependency to `pubspec.yaml`:**
```yaml
dependencies:
  ensemble_qr_scanner:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/qr_scanner
```

2. **Update `lib/generated/ensemble_modules.dart`:**
```dart
// Add import
import 'package:ensemble_qr_scanner/qr_code_scanner.dart';

// Set flag
static const useCamera = true;

// Register (inside useCamera block)
GetIt.I.registerSingleton<EnsembleQRCodeScanner>(
    EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));
```

3. **Add permissions:**

**Android** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

**iOS** (`Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Camera permission is required for QR code scanning</string>
```

## Usage

```yaml
QRCodeScanner:
  id: scanner
  initialCamera: back
  formatsAllowed: [qrcode, barcode]
  cutOutHeight: 250
  cutOutWidth: 250
  cutOutBorderRadius: 12
  cutOutBorderColor: 0xFF00FF00
  onReceived: |
    //@code
    console.log("Scanned: " + event.data.data);
```

## Properties

| Property | Type | Default |
|----------|------|---------|
| `initialCamera` | String (`back`/`front`) | `back` |
| `formatsAllowed` | Array (`qrcode`, `barcode`) | `[qrcode]` |
| `cutOutHeight` | Integer | 200 |
| `cutOutWidth` | Integer | 200 |
| `cutOutBorderRadius` | Integer | 0 |
| `cutOutBorderColor` | Color | red |

## Methods

- `flipCamera()` - Switch front/back
- `toggleFlash()` - Toggle flash
- `pauseCamera()` - Pause scanning
- `resumeCamera()` - Resume scanning

## Events

**onReceived:**
```javascript
{
  format: "qrCode",      // Format name
  data: "https://...",   // Decoded string
  rawBytes: [...]        // Raw bytes
}
```

**onInitialized:** Triggered when ready
**onPermissionSet:** Triggered on permission change

## Module Comparison

| Feature | qr_scanner | camera |
|---------|-----------|--------|
| QR/Barcode | ✅ | ✅ |
| Photo/Video | ❌ | ✅ |
| Face detection | ❌ | ✅ |
| Size | ~4KB | ~400KB+ |
| Permissions | Camera only | Camera, Location, Mic |
| Dependencies | mobile_scanner | geolocator, sensors, ML kit |

## When to Use

**Use `ensemble_qr_scanner`:**
- Only need QR/barcode scanning
- Want minimal app size
- Don't need extra permissions

**Use `ensemble_camera`:**
- Need photo/video capture
- Need face detection
- Need sensor/location features
- (includes QR via re-export)

## Migration from Camera Module

**Before:**
```yaml
dependencies:
  ensemble_camera: ^0.0.1
```

**After:**
```yaml
dependencies:
  ensemble_qr_scanner: ^0.0.1
```

Code remains the same - just update dependency!

## Supported Formats

- QR Code
- Code 128, Code 39, Code 93
- EAN-8, EAN-13
- UPC-A, UPC-E
- Codabar

## License

See [LICENSE](LICENSE) file.
