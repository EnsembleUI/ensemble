# dapp

`dapp` is a Dart command-line example package for `ensemble_walletconnect`.

## Overview

This example package depends on the parent `ensemble_walletconnect` package by local path. The checked-in `bin/dapp.dart` file is currently empty, so no runnable dApp flow is documented here.

## Features

- Declares a local path dependency on `ensemble_walletconnect`.
- Provides a command-line package structure for future dApp examples.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

Usage examples are not currently available in this package. `bin/dapp.dart` does not contain an implemented flow.

## Configuration

No additional configuration was found in this package.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | No | Dart command-line example; no Android project. |
| iOS | No | Dart command-line example; no iOS project. |
| Web | Unknown | No web target was found. |
| macOS | Unknown | Dart command-line support depends on the local Dart runtime. |
| Windows | Unknown | Dart command-line support depends on the local Dart runtime. |
| Linux | Unknown | Dart command-line support depends on the local Dart runtime. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `ensemble_walletconnect` | Dependency | Parent WalletConnect package used by this example. |

## Development

```bash
melos bootstrap
melos exec --scope="dapp" -- dart analyze
melos exec --scope="dapp" -- dart test
```

## Testing

A `test/` directory exists for this example package.

## Related Packages / Modules

- `ensemble_walletconnect`: parent package used by this example.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
