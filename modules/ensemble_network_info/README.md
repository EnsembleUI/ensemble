# ensemble_network_info

`ensemble_network_info` implements Ensemble's network-info manager for Wi-Fi-related data.

## Overview

This is a native module for Ensemble apps that need Wi-Fi network details. `NetworkInfoImpl` implements the Ensemble `NetworkInfoManager` stub using `network_info_plus` and checks location service/permission state through `geolocator` for Wi-Fi SSID/BSSID access.

## Features

- Reads Wi-Fi name, BSSID, IPv4, IPv6, gateway IP, broadcast address, and subnet mask.
- Returns an `InvokableNetworkInfo` model from `getNetworkInfo`.
- Requests location permission when needed by `getLocationStatus`.
- Returns `null` for Wi-Fi name and BSSID on web.
- Removes Android's surrounding quotes from Wi-Fi names when present.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

Host apps must configure location permissions required by the target OS and by `network_info_plus` for Wi-Fi SSID/BSSID access.

## Usage

The manager implementation is consumed through Ensemble's network-info stub:

```dart
import 'package:ensemble_network_info/network_info.dart';

final info = await NetworkInfoImpl().getNetworkInfo();
```

No verified Ensemble YAML example was found in this package.

## Configuration

No package-local configuration keys were found.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | Source checks `Platform.isAndroid` for Wi-Fi name/BSSID handling. |
| iOS      | Yes | Source checks `Platform.isIOS` for Wi-Fi name/BSSID handling. |
| Web      | No | Source returns `null` for Wi-Fi name and BSSID on web. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

The source uses `Geolocator.checkPermission()` and `Geolocator.requestPermission()` before reading location-gated network data. Purpose: Wi-Fi SSID/BSSID access can require location permission on Android and iOS.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `NetworkInfoImpl` | Class | Ensemble network-info manager implementation. |
| `getWifiName` | Method | Reads the current Wi-Fi name when supported. |
| `getWifiBSSID` | Method | Reads the Wi-Fi BSSID when supported. |
| `getWifiIPv4`, `getWifiIPv6` | Methods | Read Wi-Fi IP addresses. |
| `getWifiGatewayIP`, `getWifiBroadcast`, `getWifiSubmask` | Methods | Read additional Wi-Fi network details. |
| `getLocationStatus` | Method | Checks location service and permission status. |
| `getNetworkInfo` | Method | Returns all supported Wi-Fi fields in an `InvokableNetworkInfo`. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_network_info" -- flutter analyze
melos exec --scope="ensemble_network_info" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble` provides `NetworkInfoManager`, `InvokableNetworkInfo`, and location status models.
- `network_info_plus` provides Wi-Fi network data.
- `geolocator` provides location permission and service checks.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
