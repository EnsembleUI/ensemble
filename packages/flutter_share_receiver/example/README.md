# flutter_share_receiver_example

Example Flutter app for the `flutter_share_receiver` plugin.

## Overview

This example demonstrates receiving shared text, URLs, images, videos, and files through the local `flutter_share_receiver` package.

## Features

- Uses `flutter_share_receiver` through a local path dependency.
- Demonstrates share handling in `lib/main.dart`.
- Includes Android intent filters and an iOS share-extension setup in the example project.

![Demo](./demo.gif)

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

Android and iOS setup is demonstrated in the example platform folders. See the plugin README for the full host-app setup.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | `android/` example runner is present. |
| iOS      | Yes | `ios/` example runner and share-extension files are present. |
| Web      | No | The plugin pubspec declares Android and iOS plugin platforms only. |
| macOS    | No | The plugin pubspec declares Android and iOS plugin platforms only. |
| Windows  | No | The plugin pubspec declares Android and iOS plugin platforms only. |
| Linux    | No | The plugin pubspec declares Android and iOS plugin platforms only. |

## Permissions

The example Android manifest declares `android.permission.READ_EXTERNAL_STORAGE`. Purpose: reading shared media/files in the example app.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `ReceiveSharingIntent` | Class | Plugin entry point used to receive shared content. |
| `SharedMediaFile` | Model | Represents shared media/file data. |

## Development

```bash
melos bootstrap
melos exec --scope="flutter_share_receiver_example" -- flutter analyze
melos exec --scope="flutter_share_receiver_example" -- flutter test
```

## Testing

The example includes `test/widget_test.dart`.

## Related Packages / Modules

- `flutter_share_receiver` is used through a local path dependency.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.

