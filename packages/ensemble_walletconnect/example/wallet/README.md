# wallet

Command-line wallet example for `ensemble_walletconnect`.

## Overview

This example demonstrates wallet-side WalletConnect flows using the local `ensemble_walletconnect` package.

## Features

- Uses `ensemble_walletconnect` through a local path dependency.
- Provides a Dart command-line entry point under `bin/`.
- Includes example test coverage under `test/`.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

## Usage

Run the example from this directory:

```bash
dart run
```

## Configuration

No additional configuration was found in this example.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | No | Dart command-line example. |
| iOS      | No | Dart command-line example. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Dart command-line example may run where Dart is available; not otherwise verified. |
| Windows  | Unknown | Dart command-line example may run where Dart is available; not otherwise verified. |
| Linux    | Unknown | Dart command-line example may run where Dart is available; not otherwise verified. |

## Permissions

No runtime permissions were found in this example.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `ensemble_walletconnect` | Package | WalletConnect package used by this example. |

## Development

```bash
melos bootstrap
melos exec --scope="wallet" -- dart analyze
melos exec --scope="wallet" -- dart test
```

## Testing

The example includes `test/wallet_test.dart`.

## Related Packages / Modules

- `ensemble_walletconnect` is used through a local path dependency.
- `algorand_dart` is listed as a dependency.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
