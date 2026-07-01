# Ensemble Runtime

Build Flutter apps from Ensemble's declarative YAML definitions.

The `ensemble` package is the core runtime used by Ensemble host apps. It loads app configuration, fetches or reads screen definitions, interprets Ensemble Declarative Language (EDL), registers built-in widgets/actions, manages runtime state, and provides navigation helpers for embedding Ensemble screens in a Flutter app.

## When To Use This Package

Use `ensemble` when you want a Flutter host app to render Ensemble definitions from:

- CDN-hosted app bundle
- local YAML files bundled with your Flutter app

For a complete runnable host app, start from the Ensemble starter app in the repository. This package is the runtime dependency that powers that host app.

## Features

- Loads local, remote, CDN, and Ensemble-hosted app definitions.
- Renders the core Ensemble widget set, including forms, layouts, navigation, media, charts, calendars, web views, and rich inputs.
- Executes built-in actions for navigation, API calls, storage, files, notifications, permissions, sockets, authentication hooks, and more.
- Provides runtime services for theming, data binding, localization, storage, secrets, app configuration, and module extension points.
- Supports optional modules through `GetIt` registration while keeping the core runtime usable on its own.

## Installation

Add the runtime to your Flutter app:

```bash
flutter pub add ensemble
```

Then import the runtime:

```dart
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
```

## Basic Usage

The simplest host-app pattern initializes any optional modules first, then runs `EnsembleApp`:

```dart
import 'package:ensemble/ensemble_app.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(EnsembleApp());
}
```

To embed Ensemble in an existing Flutter app, initialize the runtime and navigate into the configured Ensemble app:

```dart
await Ensemble().initialize();
await Ensemble().navigateApp(context);
```

## Configuration

The runtime reads `ensemble/ensemble-config.yaml` from your Flutter app bundle. A typical local configuration looks like this:

```yaml
definitions:
  from: local
  local:
    path: ensemble/apps/my_app
```

For Ensemble Cloud / Studio apps, configure `definitions.from: ensemble` with the app id and account settings required by your project.

When `definitions.from` is `ensemble`, the runtime initializes Firebase with Ensemble's bundled public project options. These Firebase API keys identify the public Ensemble backend project and are not treated as private secrets. Production host apps that use their own Firebase services should provide their own configuration where needed.

## Bundled Assets

Host apps should include their Ensemble app files and configuration as Flutter assets. For example:

```yaml
flutter:
  assets:
    - ensemble/
```

The runtime package also ships default images, fonts, icon fonts, schemas, and localization assets used by built-in widgets.

## Platform Notes

`ensemble` is a Flutter package, not a platform plugin. It is designed to run inside a host Flutter app. Android, iOS, and web support depends on the host app configuration and on which runtime actions/widgets are used.

Some features require host-app platform setup, such as camera, location, contacts, files, notifications, deep links, authentication, local network, or background work permissions.

## Optional Modules

Some integrations are implemented as separate Ensemble modules and are registered at app startup. Examples include auth providers, analytics, camera, contacts, location, Bluetooth, Stripe, and other native integrations.

The core runtime includes stubs and extension points for these modules so apps can include only the integrations they need.

## Main APIs

- `Ensemble` initializes runtime services and exposes navigation helpers.
- `EnsembleApp` provides the standard app widget for rendering a configured Ensemble app.
- `EnsembleConfig` represents runtime configuration loaded from `ensemble-config.yaml`.
- `EnsembleAction` and `ActionType` define the core action model used by EDL.

## Documentation

- [Reusable Actions](doc/reusable-actions.md)
- [Layout widgets](doc/layout-widgets.md)
- [Runtime security and data bindings](doc/runtime-security-and-data-bindings.md)

## Development

For repository development, bootstrap the Melos workspace first:

```bash
melos bootstrap
```

Useful package-level commands:

```bash
melos exec --scope="ensemble" -- flutter analyze
melos exec --scope="ensemble" -- flutter test
```

## Repository

Source code, starter app, optional modules, and supporting packages are maintained in the [Ensemble repository](https://github.com/EnsembleUI/ensemble).