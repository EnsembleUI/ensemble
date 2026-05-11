# ensemble_network_info

`ensemble_network_info` provides Wi-Fi and network metadata to Ensemble through `network_info_plus`.

## Overview

This is an optional native-capability module. `NetworkInfoImpl` implements Ensemble's `NetworkInfoManager` contract and returns Wi-Fi name, BSSID, IP addresses, gateway, broadcast address, subnet mask, and location-permission status.

## Features

- Reads Wi-Fi name, BSSID, IPv4, IPv6, gateway IP, broadcast address, and subnet mask.
- Returns all network fields together through `getNetworkInfo()`.
- Checks and requests location permission before mobile Wi-Fi SSID/BSSID access.
- Returns `null` for Wi-Fi name and BSSID on web according to the source code.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified entry point is `NetworkInfoImpl` in `lib/network_info.dart`. The core runtime contains network-info action wiring, but this package does not include a complete Ensemble YAML example. Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

No additional configuration was found in this package. Host apps must configure platform location permissions when Wi-Fi SSID/BSSID access requires them.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Yes | Source checks `Platform.isAndroid` for Wi-Fi name and BSSID access. |
| iOS | Yes | Source checks `Platform.isIOS` for Wi-Fi name and BSSID access. |
| Web | No | Source returns `null` for Wi-Fi name and BSSID when `kIsWeb` is true. |
| macOS | Unknown | No macOS-specific evidence was found. |
| Windows | Unknown | No Windows-specific evidence was found. |
| Linux | Unknown | No Linux-specific evidence was found. |

## Permissions

The source checks `Geolocator.isLocationServiceEnabled()`, checks location permission, and requests permission when it is denied. Platform manifest entries and iOS usage descriptions are not declared in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `NetworkInfoImpl` | Service | Implements Ensemble's `NetworkInfoManager` using `network_info_plus`. |
| `getNetworkInfo()` | Method | Returns an `InvokableNetworkInfo` with the available Wi-Fi metadata. |
| `getLocationStatus()` | Method | Returns the current location permission/service status used by Wi-Fi metadata calls. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_network_info" -- flutter analyze
melos exec --scope="ensemble_network_info" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble`: defines `NetworkInfoManager`, network-info actions, and `InvokableNetworkInfo`.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
