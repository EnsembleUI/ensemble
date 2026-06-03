# mobile_dapp

`mobile_dapp` is a Flutter WalletConnect example app that demonstrates Ethereum and Algorand transaction flows with QR display.

## Overview

This example depends on `ensemble_walletconnect`, `web3dart`, `url_launcher`, and `qr_flutter`. `lib/main.dart` lets the user select Ethereum or Algorand, starts a WalletConnect transaction flow, displays a WalletConnect URI as a QR code, and disconnects the session.

## Features

- Demonstrates WalletConnect lifecycle handling through `WalletConnectLifecycle`.
- Demonstrates Ethereum and Algorand transaction tester classes.
- Displays the generated WalletConnect URI with `QrImageView`.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

Run the example from this directory with Flutter tooling, or use Melos from the repository root:

```bash
melos exec --scope="mobile_dapp" -- flutter run
```

## Configuration

No additional configuration was found in this example README. Wallet/deep-link behavior depends on the target device, installed wallet apps, and the transaction tester configuration in `lib/`.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Yes | Android runner project is present. |
| iOS | Yes | iOS runner project is present. |
| Web | Yes | Web runner project is present. |
| macOS | Yes | macOS runner project is present. |
| Windows | Unknown | No Windows runner project was found. |
| Linux | Unknown | No Linux runner project was found. |

## Permissions

No runtime permissions were found in this example README. Check platform files before adding wallet deep-link or network capabilities.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `WalletConnectLifecycle` | Widget | Example helper that tracks WalletConnect session lifecycle. |
| `TransactionTester` | Class | Example abstraction for Ethereum and Algorand transfer flows. |

## Development

```bash
melos bootstrap
melos exec --scope="mobile_dapp" -- flutter analyze
melos exec --scope="mobile_dapp" -- flutter test
```

## Testing

A `test/` directory exists and currently contains a default widget test.

## Related Packages / Modules

- `ensemble_walletconnect`: parent WalletConnect package used by this example.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
