# ensemble_app_badger_example

Example Flutter app for the `ensemble_app_badger` plugin.

## Overview

This example demonstrates updating and removing app launcher badges through the local `ensemble_app_badger` package.

## Features

- Uses `ensemble_app_badger` through a local path dependency.
- Demonstrates the plugin API from a Flutter app.

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
| Web      | No | The plugin does not declare web support. |
| macOS    | Unknown | The plugin declares macOS support, but no macOS example runner was found. |
| Windows  | No | The plugin does not declare Windows support. |
| Linux    | No | The plugin does not declare Linux support. |

## Permissions

No runtime permissions were found in this example.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `FlutterAppBadger` | Class | Static API for updating and removing badge counts. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_app_badger_example" -- flutter analyze
melos exec --scope="ensemble_app_badger_example" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble_app_badger` is used through a local path dependency.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
