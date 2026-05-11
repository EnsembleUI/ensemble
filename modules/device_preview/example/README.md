# device_preview example

Example Flutter app for the local `device_preview` package.

## Overview

This example demonstrates the vendored `device_preview` package through a local path dependency.

## Features

- Uses `device_preview` from the parent directory.
- Provides a Flutter app scaffold for trying the device preview UI.

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
| `device_preview` | Package | Local package demonstrated by this example app. |

## Development

```bash
melos bootstrap
melos exec --scope="example" -- flutter analyze
melos exec --scope="example" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `device_preview` is used through a local path dependency.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
