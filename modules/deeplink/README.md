# ensemble_deeplink

`ensemble_deeplink` implements deferred deep-link support for Ensemble using Branch.

## Overview

This is an optional integration module. `DeferredLinkManagerImpl` implements the core deferred-link manager contract and currently handles `DeepLinkProvider.branch` through `flutter_branch_sdk`.

## Features

- Initializes Branch deferred deep links for the Branch provider.
- Creates Branch Universal Objects and link properties from Ensemble deep-link input.
- Throws a `LanguageError` for providers that are not implemented in this package.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified entry point is `DeferredLinkManagerImpl` in `lib/deferred_link_manager.dart`. No complete Ensemble YAML example was found in this package. Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

Branch setup is required in the host app when `DeepLinkProvider.branch` is used. Branch keys, URL schemes, App Links, and Universal Links were not found in this package.

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

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `DeferredLinkManagerImpl` | Service | Implements Branch-backed deferred deep-link initialization and link creation. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_deeplink" -- flutter analyze
melos exec --scope="ensemble_deeplink" -- flutter test
```

## Testing

A `test/` directory exists, but the current test file only imports the package and does not define tests.

## Related Packages / Modules

- `ensemble`: defines the deep-link provider enum and manager contract used by this implementation.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
