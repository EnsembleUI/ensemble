# mobile_dapp

Flutter mobile dApp example for `ensemble_walletconnect`.

## Overview

This example demonstrates a Flutter dApp that uses the local `ensemble_walletconnect` package along with QR/deep-link helper dependencies.

## Features

- Uses `ensemble_walletconnect` through a local path dependency.
- Includes `qr_flutter`, `url_launcher`, `web3dart`, and `algorand_dart` dependencies.
- Provides a Flutter example app with Android, iOS, and macOS runner folders.

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

No additional configuration was found in this example.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Yes | `android/` example runner is present. |
| iOS      | Yes | `ios/` example runner is present. |
| Web      | Unknown | No `web/` runner was found. |
| macOS    | Yes | `macos/` example runner is present. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

No runtime permissions were found in this example.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `ensemble_walletconnect` | Package | WalletConnect package used by this example. |

## Development

```bash
melos bootstrap
melos exec --scope="mobile_dapp" -- flutter analyze
melos exec --scope="mobile_dapp" -- flutter test
```

## Testing

The example includes `test/widget_test.dart`.

## Related Packages / Modules

- `ensemble_walletconnect` is used through a local path dependency.
- `qr_flutter`, `url_launcher`, `web3dart`, and `algorand_dart` are listed dependencies.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
