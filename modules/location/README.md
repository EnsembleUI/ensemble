# ensemble_location

`ensemble_location` registers Ensemble location services and a Google Maps-backed `Map` widget.

## Overview

This is a native/integration module for Ensemble apps. `LocationModuleImpl` registers `LocationManagerImpl` and an `EnsembleMapWidget` factory with `GetIt`. The map widget implements the `EnsembleMap` stub and exposes marker templating, camera movement, current bounds, toolbar controls, and location-related options.

## Features

- Registers Ensemble's `LocationManager` implementation.
- Registers the `Map` widget implementation.
- Supports map camera movement, bounds movement, and auto-zoom methods.
- Supports templated markers with image, icon, widget, selected marker, overlay widget, and marker callbacks.
- Supports map toolbar options and current-location display flags.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

Host apps must configure `google_maps_flutter` for their target platforms, including any required API keys and native setup.

## Usage

Verified widget type:

```yaml
Map:
  id: map
```

Additional YAML examples are not included because a complete source-verified example was not found in this package.

## Configuration

Verified `Map` setters include:

- Size and camera: `width`, `height`, `initialCameraPosition`, `initialCameraZoom`
- Zoom and location: `autoZoom`, `autoZoomPadding`, `locationEnabled`, `includeCurrentLocationInAutoZoom`
- Gestures: `rotateEnabled`, `scrollEnabled`, `tiltEnabled`, `zoomEnabled`
- Toolbar: `showToolbar`, `showMapTypesButton`, `showLocationButton`, `showZoomButtons`, `toolbarMargin`, `toolbarAlignment`, `toolbarTop`, `toolbarBottom`, `toolbarLeft`, `toolbarRight`
- Markers: `markers`, `fixedMarker`, `draggableMarker`, `scrollableMarkerOverlay`, `dismissibleMarkerOverlay`, `autoSelect`
- Events: `onMapCreated`, `onCameraMove`

Verified methods are `runAutoZoom`, `moveCamera`, and `moveCameraBounds`. Verified getter is `currentBounds`.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Uses Google Maps and geolocation plugins; no package-level Android folder was found. |
| iOS      | Unknown | Uses Google Maps and geolocation plugins; no package-level iOS folder was found. |
| Web      | Unknown | Source mentions web-only zoom buttons, but no package-level web folder was found. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

The module depends on `geolocator`. No platform permission declarations were found in this package, so host apps must configure location permissions and map API keys for the platforms they enable.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `LocationModuleImpl` | Class | Registers location manager and map widget implementations. |
| `LocationManagerImpl` | Class | Ensemble location manager implementation. |
| `EnsembleMapWidget` | Widget | Google Maps-backed Ensemble `Map` widget. |
| `MyController` | Controller | Stores map configuration, callbacks, marker templates, and map actions. |
| `MarkerItemTemplate` | Model | Describes marker data and templates. |
| `MarkerTemplate` | Model | Describes image, icon, or custom widget marker templates. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_location" -- flutter analyze
melos exec --scope="ensemble_location" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble` provides location and map stub interfaces.
- `ensemble_ts_interpreter` provides invokable support.
- `google_maps_flutter` and `geolocator` provide map and location capabilities.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.