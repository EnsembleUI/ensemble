# Ensemble Device Preview

`ensemble_device_preview` provides a Flutter `DevicePreview` wrapper and preview tooling for testing app layouts against different devices and settings.

## Overview

This is a Flutter utility package used by Ensemble development tooling. The public barrel `lib/ensemble_device_preview.dart` exports `DevicePreview`, preview state, stores, storage implementations, locales, screenshots, and toolbar sections.

## Features

- Wraps an app with `DevicePreview` for device-frame and settings previews.
- Exposes preview state through `DevicePreviewData` and `DevicePreviewStore`.
- Includes default toolbar tools and extension points for custom tools.
- Supports persisted preferences through storage classes exported by the package.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

A source-verified usage pattern is available in `example/lib/main.dart`:

```dart
import 'package:ensemble_device_preview/ensemble_device_preview.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      tools: [
        ...DevicePreview.defaultTools,
      ],
      builder: (context) => const BasicApp(),
    ),
  );
}
```

## Configuration

No additional configuration was found in this package. Preview behavior is configured through `DevicePreview` constructor arguments and `DevicePreviewData`.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Unknown | No Android project or plugin declaration is included in this package. |
| iOS | Unknown | No iOS project or plugin declaration is included in this package. |
| Web | Unknown | No Web project or plugin declaration is included in this package. |
| macOS | Unknown | No macOS project or plugin declaration is included in this package. |
| Windows | Unknown | No Windows project or plugin declaration is included in this package. |
| Linux | Unknown | No Linux project or plugin declaration is included in this package. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `DevicePreview` | Widget | Main preview wrapper. |
| `DevicePreviewData` | Class | Holds preview state such as device, locale, orientation, and accessibility settings. |
| `DevicePreviewStore` | Class | Stores and updates preview data. |
| `PreferencesDevicePreviewStorage` | Class | Persists preview preferences. |
| `FileDevicePreviewStorage` | Class | File-backed preview storage implementation. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_device_preview" -- flutter analyze
melos exec --scope="ensemble_device_preview" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `packages/ensemble_device_preview/example`: source-verified Flutter example for this package.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
