# ensemble_moengage

`ensemble_moengage` implements Ensemble's MoEngage module using the MoEngage Flutter SDK and Firebase Messaging.

## Overview

This is an integration module for Ensemble apps. `MoEngageImpl` implements the Ensemble `MoEngageModule` stub, initializes `MoEngageFlutter`, configures push callbacks, requests push notification permissions, and exposes event, user, device, inbox, card, and geofence operations.

## Features

- Initializes MoEngage with a workspace ID and optional verbose logging.
- Requests push notification permission through Firebase Messaging on iOS and MoEngage on Android.
- Tracks events and user attributes.
- Enables and disables data, device ID, Android ID, and advertising ID tracking.
- Exposes push registration, inbox, cards, geofence, and app status methods through the module implementation.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

Host apps must configure MoEngage, Firebase Messaging, and native push notification setup for the platforms they enable.

## Usage

The module is initialized with a MoEngage workspace ID:

```dart
import 'package:ensemble_moengage/moengage.dart';

await MoEngageImpl(workspaceId: workspaceId).initialize(workspaceId);
```

No verified Ensemble YAML example was found in this package.

## Configuration

Verified initialization inputs:

| Key | Type | Description |
| --- | ---- | ----------- |
| `workspaceId` | `String` | Required MoEngage workspace ID. |
| `enableLogs` | `bool` | Enables verbose MoEngage SDK logs when true. |

The implementation creates `MoEInitConfig` with `PushConfig(shouldDeliverCallbackOnForegroundClick: true)` and an `AnalyticsConfig` that does not track boolean user attributes as numbers.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | Source calls Android push permission APIs and imports `dart:io`. |
| iOS      | Yes | Source calls `FirebaseMessaging.requestPermission` for iOS. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

The source requests notification permission on iOS through `FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true)` and calls `requestPushPermissionAndroid()` for Android. Purpose: push notifications for MoEngage messaging.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `MoEngageImpl` | Class | Ensemble MoEngage module implementation. |
| `initialize` | Method | Initializes MoEngage and notification handling. |
| `trackEvent` | Method | Sends a named event with optional properties. |
| `setUniqueId`, `setUserName`, `setEmail`, `setPhoneNumber` | Methods | Sets verified user identity and profile fields. |
| `registerForPushNotification` | Method | Registers for MoEngage push notifications. |
| `MoEngageNotificationHandler` | Class | Handles MoEngage notification callbacks. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_moengage" -- flutter analyze
melos exec --scope="ensemble_moengage" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble` provides the MoEngage stub interface and property models.
- `moengage_flutter`, `moengage_cards`, `moengage_geofence`, `moengage_inbox`, and `firebase_messaging` provide the SDK integrations.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
