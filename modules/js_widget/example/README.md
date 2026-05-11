# js_widget_example

This Flutter example demonstrates `JsWidget` by rendering a Chart.js line chart from HTML, JavaScript configuration, and the Chart.js CDN script.

## Overview

This is an example package in the Melos workspace. It depends on the parent `js_widget` package by local path and is intended for manual verification of that package's public API.

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
melos exec --scope="js_widget_example" -- flutter run
```

## Configuration

No additional configuration was found in this example README. Check the parent package README for platform setup and permissions.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Yes | Android runner project is present. |
| iOS | Yes | iOS runner project is present. |
| Web | Yes | Web runner project is present. |
| macOS | Unknown | No macOS runner project was found. |
| Windows | Unknown | No Windows runner project was found. |
| Linux | Unknown | No Linux runner project was found. |

## Permissions

No new permissions are documented here. Check the example platform files and the parent package README before enabling device capabilities.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `js_widget` | Dependency | Parent package demonstrated by this example. |

## Development

```bash
melos bootstrap
melos exec --scope="js_widget_example" -- flutter analyze
melos exec --scope="js_widget_example" -- flutter test
```

## Testing

No package-specific tests were found unless the example `test/` directory is present.

## Related Packages / Modules

- `js_widget`: parent package used by this example.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
