# js_widget_example

Example Flutter app demonstrating `js_widget` with Chart.js integration.

## Overview

This example app depends on the local `js_widget` package and shows how the package can render HTML/JavaScript content from Flutter.

## Features

- Uses a path dependency on `../`.
- Includes `assets/chart.min.js` in `pubspec.yaml`.
- Targets the package's web and mobile WebView implementations through the same `js_widget` API.

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

The example registers `assets/chart.min.js` as a Flutter asset. No additional configuration was found in this example.

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
| `js_widget` | Package | Local package demonstrated by this example. |

## Development

```bash
melos bootstrap
melos exec --scope="js_widget_example" -- flutter analyze
melos exec --scope="js_widget_example" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `js_widget` is used through a local path dependency.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
