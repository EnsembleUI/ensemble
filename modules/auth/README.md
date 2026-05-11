# ensemble_auth

`ensemble_auth` registers authentication services and sign-in widgets for Ensemble apps.

## Overview

This is an optional integration module for Ensemble authentication. `AuthModuleImpl` registers concrete implementations with `GetIt`, including Google sign-in, Apple sign-in, Microsoft connect, anonymous sign-in, custom-token sign-in, token management, and OAuth handling.

## Features

- Registers auth context, token, OAuth, and sign-in implementations for the core runtime.
- Provides `SignInWithGoogle` and `SignInWithApple` widget implementations.
- Provides Google and Microsoft connect widget implementations.
- Includes server/API, anonymous, custom-token, and verification-code sign-in support in source.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified entry point is `AuthModuleImpl` in `lib/auth_module.dart`. The module registers widgets and services; complete app-level YAML examples were not found in this package. Usage examples are not currently available in this package. See the source files under `lib/` and the test under `test/` for implementation details.

## Configuration

The source depends on Firebase Auth, Google Sign-In, Sign in with Apple, and `flutter_web_auth_2`. Provider-specific client IDs, URL schemes, Firebase files, and Apple/Google setup are host-app configuration and were not found in this package.

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

No runtime permissions were found in this package. OAuth URL schemes, associated domains, and provider entitlements must be configured in the host app when required by the selected auth provider.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `AuthModuleImpl` | Module | Registers auth services and widgets with `GetIt`. |
| `TokenManagerImpl` | Service | Implements Ensemble token management. |
| `OAuthControllerImpl` | Controller | Handles OAuth connection flows. |
| `SignInWithGoogleImpl` | Widget | Google sign-in button implementation. |
| `SignInWithAppleImpl` | Widget | Apple sign-in button implementation. |
| `ConnectWithGoogleImpl` | Widget | Google account connection widget. |
| `ConnectWithMicrosoftImpl` | Widget | Microsoft account connection widget. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_auth" -- flutter analyze
melos exec --scope="ensemble_auth" -- flutter test
```

## Testing

The package has a `test/` directory, including `test/sign_in_with_phone_test.dart`.

## Related Packages / Modules

- `ensemble`: defines the auth stubs and widget contracts implemented by this module.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
