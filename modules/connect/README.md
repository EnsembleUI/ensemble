# ensemble_connect

`ensemble_connect` connects Ensemble's Plaid Link stub to the `plaid_flutter` plugin.

## Overview

This is an integration module for Ensemble apps that need to open Plaid Link. `PlaidLinkManagerImpl` implements the Ensemble `PlaidLinkManager` stub, opens Plaid Link with a link token, and maps Plaid success, event, and exit callbacks into JSON-like maps.

## Features

- Opens Plaid Link using `LinkTokenConfiguration(token: plaidLink)`.
- Subscribes to Plaid success, event, and exit streams.
- Converts Plaid success metadata, institution, and account fields to maps for Ensemble callbacks.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

The host app is responsible for obtaining a Plaid Link token and completing any native setup required by `plaid_flutter`.

## Usage

The manager implementation exposes `openPlaidLink` through the Ensemble stub:

```dart
import 'package:ensemble_connect/plaid_link/plaid_link_manager.dart';

PlaidLinkManagerImpl().openPlaidLink(
  linkToken,
  onSuccess,
  onEvent,
  onExit,
);
```

No verified Ensemble YAML example was found in this package.

## Configuration

No package-local configuration keys were found. Plaid environment, products, redirect URIs, and account-linking settings are expected to be handled by the Plaid backend and host app.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Uses `plaid_flutter`; no package-level Android folder was found. |
| iOS      | Unknown | Uses `plaid_flutter`; no package-level iOS folder was found. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `PlaidLinkManagerImpl` | Class | Opens Plaid Link and forwards callbacks to Ensemble. |
| `PlaidLinkSuccess` | Model | Public token plus success metadata. |
| `PlaidLinkSuccessMetadata` | Model | Link session, institution, and account metadata. |
| `PlaidLinkInstitution` | Model | Institution ID and name. |
| `PlaidLinkAccount` | Model | Linked account ID, name, mask, type, subtype, and verification status. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_connect" -- flutter analyze
melos exec --scope="ensemble_connect" -- flutter test
```

## Testing

The package includes `test/ensemble_connect_test.dart`.

## Related Packages / Modules

- `ensemble` provides the Plaid Link stub interface.
- `plaid_flutter` provides the native Plaid Link integration.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
