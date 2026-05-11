# ensemble_deeplink

`ensemble_deeplink` integrates Ensemble's deferred deep-link manager with Branch.

## Overview

This is an integration module for Ensemble apps. `DeferredLinkManagerImpl` implements the core deferred-link stub, initializes Branch through `flutter_branch_sdk`, creates Branch short links, and forwards received deferred-link data to Ensemble callbacks.

## Features

- Initializes Branch with `useTestKey`, `enableLog`, and `disableTrack` options.
- Listens for Branch sessions and forwards link data to `DeepLinkNavigator` and optional callbacks.
- Creates Branch short URLs from universal object and link property maps.
- Handles incoming deferred links through `FlutterBranchSdk.handleDeepLink`.
- Explicitly throws `LanguageError` for AppsFlyer and Adjust providers because those providers are still in development.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

Host apps must configure Branch keys, associated domains, app links, and any required native setup for `flutter_branch_sdk`.

## Usage

The implementation is consumed through Ensemble's deferred-link stub:

```dart
import 'package:ensemble/deep_link_manager.dart';
import 'package:ensemble_deeplink/deferred_link_manager.dart';

await DeferredLinkManagerImpl().init(
  provider: DeepLinkProvider.branch,
  options: {'useTestKey': true, 'enableLog': true},
);
```

No verified Ensemble YAML example was found in this package.

## Configuration

Verified options for Branch initialization:

| Key | Type | Description |
| --- | ---- | ----------- |
| `useTestKey` | `bool` | Passed to `FlutterBranchSdk.init`. Defaults to `false`. |
| `enableLog` | `bool` | Passed as Branch `enableLogging`. Defaults to `false`. |
| `disableTrack` | `bool` | Passed as Branch `disableTracking`. Defaults to `false`. |

Verified deep-link creation maps:

- `universalProps`: uses `id`, `title`, and `imageUrl`.
- `linkProps`: uses `channel`, `feature`, `campaign`, `stage`, `tags`, and `controlParams`.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Uses `flutter_branch_sdk`; no package-level Android folder was found. |
| iOS      | Unknown | Uses `flutter_branch_sdk`; no package-level iOS folder was found. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `DeferredLinkManagerImpl` | Class | Ensemble deferred-link manager implementation. |
| `BranchLinkManager` | Class | Internal singleton wrapper around `flutter_branch_sdk`. |
| `init` | Method | Initializes Branch and registers link callbacks. |
| `createDeepLink` | Method | Creates a Branch short URL from universal and link properties. |
| `handleDeferredLink` | Method | Sends an incoming URL to Branch and forwards session data. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_deeplink" -- flutter analyze
melos exec --scope="ensemble_deeplink" -- flutter test
```

## Testing

The package includes `test/ensemble_deeplink_test.dart`.

## Related Packages / Modules

- `ensemble` provides `DeferredLinkManager`, `DeepLinkProvider`, and navigation helpers.
- `flutter_branch_sdk` provides Branch integration.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.