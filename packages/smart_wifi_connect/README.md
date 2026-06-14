# smart_wifi_connect

A lightweight Flutter plugin that allows apps to connect to a known Wi-Fi network using SSID and password.

## Features

- Connect to a Wi-Fi network by SSID and password
- Structured result with success/failure status
- Platform-appropriate APIs (iOS: `NEHotspotConfigurationManager`, Android: `WifiNetworkSpecifier`)
- No Wi-Fi scanning, no location inference, no background monitoring

## Usage

```dart
import 'package:smart_wifi_connect/smart_wifi_connect.dart';

final result = await SmartWifiConnect.connect(
  ssid: 'MyNetwork',
  password: 'MyPassword',
  joinOnce: false,
  rememberNetwork: true,
);

if (result.success) {
  print('Connected!');
} else {
  print('Failed: ${result.status} - ${result.message}');
}
```

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `ssid` | `String` | required | The Wi-Fi network name |
| `password` | `String` | required | The Wi-Fi password |
| `joinOnce` | `bool` | `false` | If true, the network is session-based (iOS only) |
| `rememberNetwork` | `bool` | `true` | If true, the device remembers the network |

## Status Values

| Status | Description |
|--------|-------------|
| `connected` | Successfully connected |
| `permissionDenied` | Required permissions were denied |
| `userCancelled` | User cancelled the connection prompt |
| `unsupported` | Platform does not support this feature |
| `invalidArguments` | Invalid parameters (e.g. empty SSID) |
| `failed` | Connection failed for another reason |

## Platform Setup

### Android

Add the following permissions to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />

<!-- Android 13+ (API 33+): use NEARBY_WIFI_DEVICES instead of location -->
<uses-permission
    android:name="android.permission.NEARBY_WIFI_DEVICES"
    android:usesPermissionFlags="neverForLocation" />

<!-- Android 12 and below: location permission required for Wi-Fi APIs -->
<uses-permission
    android:name="android.permission.ACCESS_FINE_LOCATION"
    android:maxSdkVersion="32" />

<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

**Why each permission is needed:**

- `CHANGE_WIFI_STATE` — Required to initiate Wi-Fi connections
- `NEARBY_WIFI_DEVICES` — Android 13+ replacement for location-based Wi-Fi access; `neverForLocation` flag ensures no location data is inferred
- `ACCESS_FINE_LOCATION` — Required on Android 12 and below for Wi-Fi connection APIs (capped at SDK 32)
- `INTERNET` / `ACCESS_NETWORK_STATE` — Required to use the connected network

**Minimum Android version:** API 29 (Android 10). On older devices, the plugin returns `unsupported`.

### iOS

Add the **Hotspot Configuration** capability to your app:

1. In Xcode, select your Runner target
2. Go to Signing & Capabilities
3. Click "+" and add **Hotspot Configuration**

This adds the entitlement:

```xml
<key>com.apple.developer.networking.hotspotconfiguration</key>
<true/>
```

iOS will show a native confirmation prompt when connecting. The plugin handles this and returns the appropriate result.

## Security & Privacy

- Wi-Fi passwords are never logged
- No Wi-Fi scanning is performed
- No location data is collected
- `neverForLocation` flag is used on Android 13+
- Permissions are requested only when `connect()` is called
