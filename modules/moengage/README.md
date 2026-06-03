# ensemble_moengage

`ensemble_moengage` integrates MoEngage messaging, analytics, push, cards, inbox, and geofence APIs with Ensemble.

## Overview

This is an optional integration module. `MoEngageImpl` implements the core `MoEngageModule` contract using `moengage_flutter` and related MoEngage plugins. The module also wires Firebase Messaging permission handling for push notification registration.

## Features

- Initializes the MoEngage SDK from configuration supplied by the host app or Ensemble runtime.
- Tracks events, user attributes, user identity, and push tokens through MoEngage APIs.
- Registers for push notifications and provisional push.
- Exposes MoEngage cards, inbox, geofence, and notification-click handling methods in source.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified entry point is `MoEngageImpl` in `lib/moengage.dart`. Complete Ensemble YAML examples were not found in this package. Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

MoEngage app identifiers, push setup, Firebase Messaging setup, and platform-specific MoEngage configuration are host-app concerns. This package does not include Android or iOS platform configuration files.

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

The source requests notification authorization through `FirebaseMessaging.instance.requestPermission()` on iOS and calls `requestPushPermissionAndroid()` for Android push permission handling. Platform permission declarations were not found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `MoEngageImpl` | Module | Implements Ensemble's MoEngage module contract. |
| `MoEngageNotificationHandler` | Helper | Registers notification click handlers used by the module. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_moengage" -- flutter analyze
melos exec --scope="ensemble_moengage" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble`: defines the `MoEngageModule` contract implemented by this package.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
