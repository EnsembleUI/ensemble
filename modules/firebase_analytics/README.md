# Firebase Analytics Module for Ensemble

This module provides a robust integration of Firebase Analytics and Crashlytics for Ensemble-based Flutter applications. It offers intelligent error handling, event logging, and user tracking, with support for platform-specific Firebase configurations.

## Features

- **Firebase Analytics Integration**: Log custom events and set user IDs.
- **Crashlytics Integration**: Automatically reports errors, distinguishing between fatal and non-fatal errors.
- **Platform Support**: Handles iOS, Android, and Web Firebase options.
- **Custom Error Handling**: Categorizes errors based on type, source, and context for accurate reporting.
- **Flexible Initialization**: Can use a provided `FirebaseApp` or initialize with configuration options.

## Getting Started

### 1. Configuration

Ensure you have the appropriate Firebase configuration files for your platform:
- `google-services.json` for Android
- `GoogleService-Info.plist` for iOS
- Web config in your options map (if targeting web)

You can also provide Firebase options programmatically via a configuration map.

### 2. Initialization

The main provider class is `FirebaseAnalyticsProvider`. You can initialize it with or without a provided `FirebaseApp`:

```dart
final provider = FirebaseAnalyticsProvider();
await provider.init(
  options: yourFirebaseOptionsMap, // Optional: platform-specific options
  ensembleAppId: 'yourAppId',      // Optional: for app-specific config
  shouldAwait: true,               // Optional: await initialization
);
```

If you already have a `FirebaseApp` instance:

```dart
final provider = FirebaseAnalyticsProvider(yourFirebaseApp);
await provider.init();
```

### 3. Logging Events

To log a custom event:

```dart
await provider.logEvent('event_name', {'param1': 'value1'}, LogLevel.info);
```

Or use the generic log method:

```dart
await provider.log({
  'operation': 'logEvent',
  'name': 'event_name',
  'parameters': {'param1': 'value1'},
  'logLevel': LogLevel.info,
});
```

### 4. Setting User ID

```dart
await provider.setUserId('user_id');
```

Or via the log method:

```dart
await provider.log({
  'operation': 'setUserId',
  'userId': 'user_id',
});
```

### 5. Error Handling

- Flutter and async errors are automatically reported to Crashlytics.
- Errors are categorized as fatal or non-fatal based on type and context.

## References
- Main provider: [`lib/firebase_analytics.dart`](lib/firebase_analytics.dart)
- [Firebase Analytics for Flutter](https://pub.dev/packages/firebase_analytics)
- [Firebase Crashlytics for Flutter](https://pub.dev/packages/firebase_crashlytics)

---

For more details, see the source code and comments in `lib/firebase_analytics.dart`.
