# ensemble_bluetooth

`ensemble_bluetooth` implements Ensemble's Bluetooth manager stub using `flutter_blue_plus`, `permission_handler`, and `workmanager`.

## Overview

This is a native module for Bluetooth Low Energy workflows in Ensemble apps. `BluetoothManagerImpl` streams adapter state, starts and stops scans, connects and disconnects devices, discovers services, reads and writes characteristics, subscribes to characteristic values, and supports an Android background subscription path.

## Features

- Streams Bluetooth adapter state to an optional Ensemble action.
- Turns Bluetooth on for Android through `FlutterBluePlus.turnOn`.
- Scans for BLE devices and maps advertisement data into callback maps.
- Connects, disconnects, discovers services, reads, writes, subscribes, and unsubscribes.
- Uses `workmanager` for Android background subscription tasks.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

Host apps must provide Bluetooth and location permissions required by the target OS and plugin versions.

## Usage

The manager implementation is consumed through Ensemble's Bluetooth stub:

```dart
import 'package:ensemble_bluetooth/ensemble_bluetooth.dart';

final manager = BluetoothManagerImpl();
await manager.turnOn();
```

No verified Ensemble YAML example was found in this package.

## Configuration

No package-local configuration keys were found. The source references a global script handler named `ensemble_bluetooth_handler` when characteristic values are received.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | Source uses `Platform.isAndroid`, Android Bluetooth turn-on, Android location checks, and Android background work. |
| iOS      | Unknown | BLE plugin dependency may support iOS, but no iOS-specific package files were found. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

The source checks and requests `Permission.location` before Android BLE scans and requires location services to be enabled. Bluetooth permissions are not declared in this package and must be configured in the host app for the OS versions being targeted.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `BluetoothManagerImpl` | Class | Ensemble Bluetooth manager implementation. |
| `BackgroundTaskManager` | Class | Tracks background task receive ports. |
| `init` | Method | Starts adapter-state streaming and optional Ensemble action dispatch. |
| `startScan` / `stopScan` | Methods | Starts and stops BLE scanning. |
| `connect` / `disconnect` | Methods | Manages device connections. |
| `discoverServices`, `read`, `write`, `subscribe`, `unSubscribe` | Methods | Interacts with BLE services and characteristics. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_bluetooth" -- flutter analyze
melos exec --scope="ensemble_bluetooth" -- flutter test
```

## Testing

The package includes `test/ensemble_bluetooth_test.dart`.

## Related Packages / Modules

- `ensemble` provides the Bluetooth stub interface and action execution APIs.
- `ensemble_ts_interpreter` provides `Invokable`.
- `flutter_blue_plus`, `permission_handler`, and `workmanager` provide BLE, permission, and background task support.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
