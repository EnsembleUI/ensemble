# QR Scanner Module Migration Guide

This guide explains the separation of QR code scanning functionality from `ensemble_camera` into the new `ensemble_qr_scanner` module.

## Why the Split?

The `ensemble_camera` module includes heavy dependencies:
- **geolocator** (^9.0.2) - requires location permissions
- **sensors_plus** (^7.0.0) - requires sensor access
- **face_camera** / **Google ML Kit** - heavy face detection libraries
- **face-api.js** - web-based face detection (100KB+)

If your app only needs QR scanning, these dependencies add unnecessary:
- **Bundle size** (~400KB+ of unused code)
- **Permissions** (location, sensors that you don't need)
- **Build time** (longer compilation)

## What Changed?

### New Module Structure

```
modules/
├── camera/                           # Heavy module (camera + face detection + sensors)
│   ├── lib/
│   │   ├── camera.dart              # Photo/video capture
│   │   ├── face_detection_camera.dart
│   │   └── qr_code_scanner.dart     # ← NOW JUST RE-EXPORTS
│   └── pubspec.yaml                 # Depends on qr_scanner
│
└── qr_scanner/                       # NEW: Lightweight module
    ├── lib/
    │   └── qr_code_scanner.dart     # ← ACTUAL IMPLEMENTATION
    └── pubspec.yaml                  # Only: mobile_scanner + ensemble
```

### Dependency Changes

**ensemble_camera before:**
```yaml
dependencies:
  camera: ^0.11.0+2
  face_camera: ^0.1.4
  geolocator: ^9.0.2          # ← Heavy
  sensors_plus: ^7.0.0        # ← Heavy
  mobile_scanner: ^6.0.11
  # ... more
```

**ensemble_qr_scanner (new):**
```yaml
dependencies:
  mobile_scanner: ^6.0.11     # ← ONLY THIS
  ensemble: (core framework)
```

**ensemble_camera after:**
```yaml
dependencies:
  camera: ^0.11.0+2
  face_camera: ^0.1.4
  geolocator: ^9.0.2
  sensors_plus: ^7.0.0
  ensemble_qr_scanner:        # ← ADDED
    path: ../qr_scanner
  # mobile_scanner removed (comes via qr_scanner)
```

## How Backward Compatibility Works

### The Re-export Pattern

The camera module's `qr_code_scanner.dart` now contains:

```dart
// Backward compatibility re-export
export 'package:ensemble_qr_scanner/qr_code_scanner.dart';
```

This means:
1. Old apps importing `package:ensemble_camera/qr_code_scanner.dart` → Still works ✅
2. The code actually comes from `ensemble_qr_scanner` (single source of truth)
3. No breaking changes

### Framework Stub Update

**Before:**
```dart
class EnsembleQRCodeScannerStub extends StubWidget {
  const EnsembleQRCodeScannerStub({super.key})
      : super(moduleName: 'ensemble_camera');  // ← Old
}
```

**After:**
```dart
class EnsembleQRCodeScannerStub extends StubWidget {
  const EnsembleQRCodeScannerStub({super.key})
      : super(moduleName: 'ensemble_qr_scanner');  // ← New
}
```

This tells new apps: "To use QRCodeScanner, add `ensemble_qr_scanner`"

But apps with `ensemble_camera` still work because camera re-exports it!

## Migration Paths

### Scenario 1: Existing App Using ensemble_camera (QR only)

**You have:**
```yaml
dependencies:
  ensemble_camera: ^0.0.1
```

**Your code:**
```dart
import 'package:ensemble_camera/qr_code_scanner.dart';
```

**Option A: No changes (recommended initially)**
- Everything continues to work
- Camera module pulls in qr_scanner automatically
- Zero code changes needed

**Option B: Migrate to lightweight (recommended eventually)**
```yaml
dependencies:
  ensemble_qr_scanner: ^0.0.1  # Lighter!
```

```dart
// Update import
import 'package:ensemble_qr_scanner/qr_code_scanner.dart';
```

**Benefits:**
- ✅ Smaller bundle size
- ✅ No location/sensor permissions needed
- ✅ Faster builds

### Scenario 2: Existing App Using ensemble_camera (Camera + QR)

**You have:**
```yaml
dependencies:
  ensemble_camera: ^0.0.1
```

**Your code:**
```dart
import 'package:ensemble_camera/camera.dart';
import 'package:ensemble_camera/qr_code_scanner.dart';
```

**Recommendation: No changes**
- Keep using `ensemble_camera`
- You need the heavy dependencies anyway (geolocator, sensors, face detection)
- QR scanner comes bundled via re-export
- Everything works as before

### Scenario 3: New App (QR only)

**Use the lightweight module:**
```yaml
dependencies:
  ensemble_qr_scanner: ^0.0.1
```

```dart
import 'package:ensemble_qr_scanner/qr_code_scanner.dart';
```

### Scenario 4: New App (Camera + QR)

**Option A: Just use camera module**
```yaml
dependencies:
  ensemble_camera: ^0.0.1
```

```dart
import 'package:ensemble_camera/camera.dart';
import 'package:ensemble_camera/qr_code_scanner.dart';  // Re-exported
```

**Option B: Explicit dependencies (cleaner)**
```yaml
dependencies:
  ensemble_camera: ^0.0.1
  ensemble_qr_scanner: ^0.0.1
```

```dart
import 'package:ensemble_camera/camera.dart';
import 'package:ensemble_qr_scanner/qr_code_scanner.dart';
```

## Testing the Migration

### Verify Old Apps Still Work

```bash
# App with ensemble_camera dependency
cd your_app
flutter clean
flutter pub get
flutter run
# Should work without changes
```

### Verify New Module Works

```bash
cd modules/qr_scanner
flutter pub get
flutter analyze
# Should have no errors
```

### Verify Camera Module Re-export Works

```bash
cd modules/camera
flutter pub get
flutter analyze
# Should successfully import from qr_scanner
```

## Breaking Changes

**None!** This is a fully backward-compatible refactoring.

Existing code continues to work with zero changes.

## Rollback Plan

If issues arise, rollback is simple:

1. Revert `camera/lib/qr_code_scanner.dart` to original implementation
2. Remove `ensemble_qr_scanner` dependency from camera/pubspec.yaml
3. Re-add `mobile_scanner: ^6.0.11` to camera/pubspec.yaml
4. Revert framework stub to point to `ensemble_camera`

## Timeline

- **Immediate**: Both paths work (camera re-export + direct qr_scanner)
- **Short term** (1-3 months): Document new module, encourage migration for QR-only apps
- **Long term** (6+ months): Most new apps use lightweight qr_scanner directly

## Questions?

- For QR scanning only → Use `ensemble_qr_scanner` (lightweight)
- For camera features → Use `ensemble_camera` (includes everything)
- Existing apps → No changes needed, continue working as before

## Version Compatibility

| ensemble_camera | ensemble_qr_scanner | Status |
|----------------|---------------------|---------|
| < 0.0.1 | N/A | QR code built into camera |
| >= 0.0.1 | 0.0.1+ | QR code re-exported from qr_scanner |

All versions remain compatible with existing app code.
