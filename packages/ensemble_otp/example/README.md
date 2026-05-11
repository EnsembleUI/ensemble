# example_ensemble_otp

Example Flutter app for the `ensemble_otp` package.

## Overview

This example demonstrates the `OtpPinField` widget using the local path dependency from `packages/ensemble_otp`.

## Features

- Imports `package:ensemble_otp/otp_pin_field.dart`.
- Shows `OtpPinField` with `maxLength`, `onSubmit`, `onChange`, `onCodeChanged`, custom field styles, and custom keyboard options.
- Includes Android SMS permissions in the example manifest for SMS-autofill experiments.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

## Usage

Run the example from this directory:

```bash
flutter run
```

## Configuration

No additional configuration was found in this example. SMS autofill behavior depends on platform setup and message format.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | `android/` example runner is present. |
| iOS      | Yes | `ios/` example runner is present. |
| Web      | Yes | `web/` example runner is present. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

The example Android manifest declares `android.permission.READ_SMS` and `android.permission.RECEIVE_SMS`. Purpose: SMS autofill demo support.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `OtpPinField` | Widget | OTP/PIN input widget demonstrated by the app. |
| `OtpPinFieldState` | State | Accessed through a `GlobalKey` to clear the OTP field. |
| `OtpPinFieldStyle` | Class | Demonstrates active, default, and filled field colors. |

## Development

```bash
melos bootstrap
melos exec --scope="example_ensemble_otp" -- flutter analyze
melos exec --scope="example_ensemble_otp" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

- `ensemble_otp` is used through a local path dependency.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
