# ensemble_bluetooth

`ensemble_bluetooth` implements Ensemble Bluetooth scanning and connection support using `flutter_blue_plus`.

## Overview

This is an optional native module. `BluetoothManagerImpl` extends the core `BluetoothManager` contract and uses `flutter_blue_plus`, `permission_handler`, and `workmanager` to scan, connect, read, write, and run background scan tasks.

## Features

- Starts and stops Bluetooth scans.
- Connects to Bluetooth devices and discovers services.
- Reads and writes Bluetooth characteristic values.
- Registers background scan tasks through `Workmanager`.
- Tracks background task ports with `BackgroundTaskManager`.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified entry point is `BluetoothManagerImpl` in `lib/ensemble_bluetooth.dart`. No complete Dart or Ensemble YAML example was found in this package. Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

Host apps must configure Bluetooth permissions and background execution requirements for their target platforms. No Android, iOS, or desktop platform files were found in this package.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Unknown | No Android project is included in this package; host app setup is required. |
| iOS | Unknown | No iOS project is included in this package; host app setup is required. |
| Web | Unknown | No web implementation was found in this package. |
| macOS | Unknown | No macOS project is included in this package. |
| Windows | Unknown | No Windows project is included in this package. |
| Linux | Unknown | No Linux project is included in this package. |

## Permissions

`BluetoothManagerImpl` checks and requests `Permission.location`, and also checks the location service status. Additional Bluetooth permissions required by target platforms were not declared in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `BluetoothManagerImpl` | Service | Implements Ensemble Bluetooth operations with `flutter_blue_plus`. |
| `BackgroundTaskManager` | Helper | Registers isolate ports for background Bluetooth tasks. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_bluetooth" -- flutter analyze
melos exec --scope="ensemble_bluetooth" -- flutter test
```

## Testing

A `test/` directory exists, but the current test file is a placeholder.

## Related Packages / Modules

- `ensemble`: defines the `BluetoothManager` contract implemented by this module.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
