# ensemble

`ensemble` is the core Flutter runtime for Ensemble's declarative app definitions.

## Overview

This is a core runtime package. It loads Ensemble configuration, initializes providers and managers, interprets Ensemble definitions, registers widgets and actions, and exposes navigation helpers used by host apps such as `starter`.

## Features

- Provides the `Ensemble` singleton and `EnsembleConfig` model in `lib/ensemble.dart`.
- Initializes Ensemble managers, configuration services, local assets, API providers, Firebase, and analytics providers.
- Defines core actions such as navigation, timers, code execution, URL opening, file upload, OAuth, sockets, permissions, camera, Plaid, and authentication actions.
- Maintains the core widget registry, including optional module extension points resolved through `GetIt`.

## Installation / Setup

Add the runtime to a Flutter host app:

```bash
flutter pub add ensemble
```

For local development inside this repository, bootstrap the Melos workspace:

```bash
melos bootstrap
```

## Usage

A source-verified host-app pattern is shown in `starter/lib/main.dart`:

```dart
await EnsembleModules().init();
runApp(EnsembleApp());
```

`starter/lib/integrate_existing_app_with_Ensemble.dart` also shows `Ensemble().initialize()` and `Ensemble().navigateApp(context)` for integrating Ensemble into an existing Flutter app.

## Configuration

Configuration is loaded through `EnsembleConfigService` and `EnsembleConfig` in `lib/ensemble.dart`. Host apps provide app IDs, local or remote definitions, Firebase options, providers, secrets, and module registration through the starter app or generated module files.

When `definitions.from` is `ensemble`, the runtime initializes Firebase with the bundled public Ensemble project options in `lib/firebase_options.dart`. Firebase API keys identify the public demo project and are not treated as secrets; production host apps should provide their own project configuration where needed.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Unknown | This package has no Android project; support depends on the host Flutter app. |
| iOS | Unknown | This package has no iOS project; support depends on the host Flutter app. |
| Web | Unknown | This package has no Web project; support depends on the host Flutter app. |
| macOS | Unknown | This package has no macOS project; support depends on the host Flutter app. |
| Windows | Unknown | This package has no Windows project; support depends on the host Flutter app. |
| Linux | Unknown | This package has no Linux project; support depends on the host Flutter app. |

## Permissions

No package-level platform manifests were found. Runtime actions and optional modules may require host-app permissions for camera, location, contacts, files, notifications, authentication, or other native capabilities.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `Ensemble` | Singleton class | Initializes runtime services and provides navigation helpers. |
| `EnsembleConfig` | Class | Runtime configuration model. |
| `EnsembleAction` | Base class | Base for core action execution. |
| `ActionType` | Enum | Defines core action names parsed by the runtime. |
| `widget_registry.dart` | Registry | Maps Ensemble widget types to Flutter widget factories and optional module implementations. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble" -- flutter analyze
melos exec --scope="ensemble" -- flutter test
```

## Testing

This package has a substantial `test/` directory. Run package tests with `melos exec --scope="ensemble" -- flutter test`.

## Additional technical documentation

- [Reusable Actions](doc/reusable-actions.md) — app-level and page-level Actions, `executeAction`, scoped `Import`/`Global`/`API`, and events.
- [Layout widgets (tabs, ListView scroll)](doc/layout-widgets.md) — EDL layout behavior in `lib/layout`.
- [Runtime security and data bindings](doc/runtime-security-and-data-bindings.md) — screen id validation for definition providers, `saveFile` naming, multipart upload path checks, `ensemble.storage.clear()` behavior and binding refresh, WebView TLS/reputation settings, global script handler payloads, and device metric bindings after rotation.

## Related Packages / Modules

- `starter`: host app template that initializes `EnsembleModules` and `EnsembleApp`.
- Optional modules under `modules/` implement runtime stubs and widgets resolved by this package.
- Packages under `packages/` provide supporting UI, parser, date, and integration utilities.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
