# example_ensemble_device_preview

Example Flutter app for `ensemble_device_preview`.

## Overview

This example demonstrates the local `ensemble_device_preview` package in a Flutter app.

## Features

- Uses `ensemble_device_preview` through a local path dependency.
- Includes Android, iOS, web, macOS, Windows, and Linux example runners.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

## Usage

Run the example from this directory:

```bash
flutter run
```

## Configuration

No additional configuration was found in this example.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | `android/` example runner is present. |
| iOS      | Yes | `ios/` example runner is present. |
| Web      | Yes | `web/` example runner is present. |
| macOS    | Yes | `macos/` example runner is present. |
| Windows  | Yes | `windows/` example runner is present. |
| Linux    | Yes | `linux/` example runner is present. |

## Permissions

No runtime permissions were found in this example.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `DevicePreview` | Widget | Main preview wrapper exported by `ensemble_device_preview`. |

## Development

```bash
melos bootstrap
melos exec --scope="example_ensemble_device_preview" -- flutter analyze
melos exec --scope="example_ensemble_device_preview" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble_device_preview` is used through a local path dependency.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
