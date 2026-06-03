# device_preview example

This Flutter example app demonstrates wrapping `BasicApp` with `DevicePreview` from the sibling `device_preview` package and adding a custom tool plugin.

## Overview

This is an example package in the Melos workspace. It depends on the parent `device_preview` package by local path and is intended for manual verification of that package's public API.

## Features

- Shows a runnable Flutter app for the parent package.
- Uses the local path dependency declared in `pubspec.yaml`.
- Keeps example code under `lib/`.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

Run the example from this directory with Flutter tooling, or use Melos from the repository root:

```bash
melos exec --scope="example" -- flutter run
```

## Configuration

No additional configuration was found in this example README. Check the parent package README for platform setup and permissions.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Yes | Runner project is present. |
| iOS | Yes | Runner project is present. |
| Web | Yes | Runner project is present. |
| macOS | Yes | Runner project is present. |
| Windows | Yes | Runner project is present. |
| Linux | Yes | Runner project is present. |

## Permissions

No new permissions are documented here. Check the example platform files and the parent package README before enabling device capabilities.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `device_preview` | Dependency | Parent package demonstrated by this example. |

## Development

```bash
melos bootstrap
melos exec --scope="example" -- flutter analyze
melos exec --scope="example" -- flutter test
```

## Testing

No package-specific tests were found unless the example `test/` directory is present.

## Related Packages / Modules

- `device_preview`: parent package used by this example.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
