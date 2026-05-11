# ensemble_location

`ensemble_location` adds location services and a Google Maps-backed `Map` widget to Ensemble.

## Overview

This is an optional native module. `LocationModuleImpl` registers `LocationManagerImpl` and `EnsembleMapWidget` with `GetIt`, allowing the core runtime to access device location and render the Ensemble `Map` widget.

## Features

- Implements location status and current-location lookup through `geolocator`.
- Registers the Ensemble widget type `Map`.
- Provides marker templates and map UI helpers under `lib/widget/maps/`.
- Uses `google_maps_flutter` for map rendering.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified widget type is `Map`, implemented by `EnsembleMapWidget` in `lib/widget/maps/maps.dart`. A complete, source-verified YAML example was not found in this package, so no YAML properties are documented here.

## Configuration

Host apps that render maps must configure Google Maps for their target platforms. API keys or platform setup files were not found in this package.

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

`LocationManagerImpl` checks location service status and requests location permission through `Geolocator.requestPermission()`. Platform manifest entries and iOS usage descriptions are not declared in this package and must be configured in the host app.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `LocationModuleImpl` | Module | Registers location and map services with `GetIt`. |
| `LocationManagerImpl` | Service | Implements location status and current location lookup. |
| `EnsembleMapWidget` | Widget | Ensemble widget implementation for the `Map` type. |
| `MyController` | Controller | Controller for the map widget. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_location" -- flutter analyze
melos exec --scope="ensemble_location" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble`: defines the location and map contracts implemented by this module.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
