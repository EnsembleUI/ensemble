# Ensemble QR Scanner

A lightweight QR Code and Barcode scanner module for the Ensemble Framework.

## Features

- **QR Code Scanning**: Scan QR codes in real-time
- **Barcode Support**: Supports multiple barcode formats (Code 128, Code 39, Code 93, EAN, UPC, etc.)
- **Customizable UI**: Configure scan overlay, border colors, and cutout dimensions
- **Camera Controls**: Flash toggle, camera flip, pause/resume scanning
- **Event Callbacks**: `onReceived`, `onInitialized`, `onPermissionSet`
- **Lightweight**: Minimal dependencies - no location services, sensors, or ML Kit required

## Dependencies

- **flutter**: SDK
- **ensemble**: Core Ensemble framework
- **mobile_scanner**: ^6.0.11 - QR/Barcode scanning

## Permissions

### Android
Add to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA" />
```

### iOS
Add to `Info.plist`:
```xml
<key>NSCameraUsageDescription</key>
<string>Camera permission is required for QR code scanning</string>
```

## Installation

### For new apps (lightweight option):
```yaml
dependencies:
  ensemble_qr_scanner:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/qr_scanner
```

### For existing apps using ensemble_camera:
No changes needed! The camera module re-exports this module for backward compatibility.

## Usage

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
              - barcode
            cutOutHeight: 250
            cutOutWidth: 250
            cutOutBorderRadius: 12
            cutOutBorderColor: 0xFF00FF00
            onReceived: |
              //@code
              console.log("Scanned: " + event.data.data);
            onInitialized: |
              //@code
              console.log("Scanner ready");
```

## Widget Properties

| Property | Type | Description | Default |
|----------|------|-------------|---------|
| `id` | String | Widget identifier | - |
| `initialCamera` | String | Initial camera (`back` or `front`) | `back` |
| `formatsAllowed` | Array | Formats to scan (`qrcode`, `barcode`) | `[qrcode]` |
| `cutOutHeight` | Integer | Scan area height | 200 |
| `cutOutWidth` | Integer | Scan area width | 200 |
| `cutOutBorderRadius` | Integer | Border radius of scan area | 0 |
| `cutOutBorderColor` | Color | Border color | red |
| `overlayColor` | Color | Overlay background color | - |
| `overlayMargin` | EdgeInsets | Margin for overlay | - |

## Widget Methods

| Method | Description |
|--------|-------------|
| `flipCamera()` | Switch between front and back camera |
| `toggleFlash()` | Toggle camera flash on/off |
| `pauseCamera()` | Pause scanning |
| `resumeCamera()` | Resume scanning |

## Events

### onReceived
Triggered when a code is scanned successfully.

**Event data:**
```javascript
{
  format: "qrCode",      // Format name
  data: "https://...",   // Decoded string
  rawBytes: [...]        // Raw bytes (may be null)
}
```

### onInitialized
Triggered when scanner is initialized and ready.

### onPermissionSet
Triggered when camera permission is granted or denied.

## Comparison with ensemble_camera

| Feature | ensemble_qr_scanner | ensemble_camera |
|---------|---------------------|-----------------|
| QR/Barcode scanning | ✅ | ✅ |
| Photo/Video capture | ❌ | ✅ |
| Face detection | ❌ | ✅ |
| Location services | ❌ | ✅ (geolocator) |
| Accelerometer | ❌ | ✅ (sensors_plus) |
| ML Kit / face-api.js | ❌ | ✅ (heavy) |
| Bundle size | ~4KB | ~400KB+ |
| Camera permission only | ✅ | ❌ (needs location/sensors) |

## Migration from ensemble_camera

If you're currently using `ensemble_camera` but only need QR scanning:

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

Your code remains the same - just update the dependency!

## License

See [LICENSE](LICENSE) file.

## Contributing

Contributions are welcome! Please submit issues and pull requests to the main Ensemble repository.
