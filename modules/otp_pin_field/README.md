# otp_pin_field

`otp_pin_field` provides a Flutter OTP/PIN input widget with styling, custom keyboard slots, and optional SMS autofill support.

## Overview

This is a Flutter plugin package. The public library exports `OtpPinField`, `OtpPinFieldState`, `OtpPinFieldStyle`, input-type enums, custom keyboard helpers, and cursor painting support. The plugin declaration in `pubspec.yaml` lists Android, iOS, and web implementations.

## Features

- Renders configurable OTP/PIN input fields with `OtpPinField`.
- Supports `maxLength`, callbacks for submit/change/code changes, custom styling, cursor configuration, and optional custom keyboard widgets.
- Supports optional SMS autofill through `autoFillEnable`, `smsRegex`, and `phoneNumbersHint`.
- Includes Android, iOS, and web plugin entries in `pubspec.yaml`.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

```dart
import 'package:otp_pin_field/otp_pin_field.dart';

OtpPinField(
  maxLength: 4,
  onSubmit: (value) {
    // Handle the completed PIN or OTP.
  },
  onChange: (value) {
    // Handle intermediate input changes.
  },
)
```

The example app under `example/` shows `OtpPinField`, `OtpPinFieldStyle`, `clearOtp()`, and custom keyboard slots.

## Configuration

No package-level configuration files were found. When SMS autofill is enabled, the host app must provide any required platform permissions or entitlements.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Yes | Declared in the plugin platform map. |
| iOS | Yes | Declared in the plugin platform map. |
| Web | Yes | Declared in the plugin platform map. |
| macOS | Unknown | No macOS plugin declaration was found. |
| Windows | Unknown | No Windows plugin declaration was found. |
| Linux | Unknown | No Linux plugin declaration was found. |

## Permissions

No runtime permissions were declared in the package manifest. The example Android app declares `android.permission.READ_SMS` and `android.permission.RECEIVE_SMS`, which are relevant when demonstrating SMS autofill.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `OtpPinField` | Widget | OTP/PIN input widget. |
| `OtpPinFieldState` | State | Exposes methods such as `clearOtp()` through a `GlobalKey`. |
| `OtpPinFieldStyle` | Class | Styling options for OTP/PIN boxes. |
| `OtpPinFieldInputType` | Enum | Controls plain, password, or custom mask display. |
| `CustomKeyboard` | Widget | Custom keyboard helper exported by the package. |

## Development

```bash
melos bootstrap
melos exec --scope="otp_pin_field" -- flutter analyze
melos exec --scope="otp_pin_field" -- flutter test
```

## Testing

No package-specific tests were found.

## Related Packages / Modules

No related packages or modules were verified from imports, dependencies, examples, or tests.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
