# ensemble_auth

`ensemble_auth` wires Ensemble's authentication stubs to Firebase Auth, Google Sign-In, Apple Sign-In, Microsoft OAuth, custom token sign-in, anonymous sign-in, and token storage helpers.

## Overview

This is a native/integration module for Ensemble apps. `AuthModuleImpl` registers the auth-related implementations with `GetIt` so the core Ensemble runtime can resolve sign-in widgets, connect widgets, OAuth controllers, auth context managers, and token managers.

## Features

- Registers `SignInWithGoogleImpl`, `SignInWithAppleImpl`, `ConnectWithGoogleImpl`, and `ConnectWithMicrosoftImpl`.
- Registers anonymous sign-in and custom token sign-in implementations.
- Provides OAuth controller, auth context manager, Google auth manager, and token manager code under `lib/`.
- Depends on `firebase_auth`, `firebase_core`, `google_sign_in`, `sign_in_with_apple`, and `flutter_web_auth_2`.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

Host apps that enable this module must also provide the native Firebase, OAuth, Google, Apple, and Microsoft configuration required by the corresponding Flutter plugins. No complete host-app setup file was found in this package.

## Usage

The module is initialized by constructing `AuthModuleImpl`, which registers implementations with `GetIt`:

```dart
import 'package:ensemble_auth/auth_module.dart';

AuthModuleImpl();
```

No standalone Ensemble YAML example was verified in this package. See the source files under `lib/signin/` and `lib/connect/` for implementation details.

## Configuration

Verified configuration requirements are plugin-backed rather than defined as package-local config files:

- Firebase must be configured for `firebase_core` and `firebase_auth`.
- Google Sign-In, Apple Sign-In, Microsoft OAuth, and web auth redirect settings must be configured in the host app when those providers are used.
- `SignInWithAuth0` registration is present only as commented code in `auth_module.dart`.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Flutter module metadata is present; provider-specific native setup is required in the host app. |
| iOS      | Unknown | Flutter module metadata is present; provider-specific native setup is required in the host app. |
| Web      | Unknown | Google and OAuth code includes web-specific imports, but no package-level web folder was found. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

No runtime permissions were found in this package. Authentication providers may require host-app URL schemes, entitlements, or Firebase configuration, but those are not declared in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `AuthModuleImpl` | Class | Registers Ensemble auth and connect implementations with `GetIt`. |
| `TokenManagerImpl` | Class | Token manager registered as the `TokenManager` singleton. |
| `OAuthControllerImpl` | Class | OAuth controller implementation registered for Ensemble. |
| `SignInAnonymousImpl` | Class | Anonymous sign-in implementation. |
| `SignInWithCustomTokenImpl` | Class | Custom-token sign-in implementation. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_auth" -- flutter analyze
melos exec --scope="ensemble_auth" -- flutter test
```

## Testing

The package includes `test/sign_in_with_phone_test.dart`.

## Related Packages / Modules

- `ensemble` provides the auth stub interfaces consumed by this module.
- `ensemble_ts_interpreter` is listed as a dependency.
- Firebase, Google, Apple, and OAuth Flutter plugins provide the provider integrations.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.