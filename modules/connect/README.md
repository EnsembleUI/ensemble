# ensemble_connect

`ensemble_connect` connects Ensemble's Plaid action stub to the `plaid_flutter` SDK so Ensemble apps can open Plaid Link from the runtime.

## Overview

This is an optional integration module. `PlaidLinkManagerImpl` extends the `PlaidLinkManager` stub from the core `ensemble` package. The core runtime calls that manager from the `openPlaidLink` action when the module is registered by a host app.

## Features

- Opens Plaid Link with a link token through `PlaidLinkManagerImpl.openPlaidLink`.
- Forwards Plaid success and event callbacks into Ensemble action callbacks.
- Converts Plaid success metadata, institutions, and accounts into invokable data objects.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified public entry point is `PlaidLinkManagerImpl` in `lib/plaid_link/plaid_link_manager.dart`. The Ensemble YAML action syntax is defined in the core runtime; this module provides the Plaid implementation used by that action. Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

The implementation requires a Plaid `link_token`; the core action reports an error when the token is missing. No additional configuration files were found in this package.

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

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `PlaidLinkManagerImpl` | Class | Implements Ensemble's `PlaidLinkManager` by opening Plaid Link with `plaid_flutter`. |
| `PlaidLinkSuccess` | Class | Invokable success payload returned from Plaid Link. |
| `PlaidLinkSuccessMetadata` | Class | Invokable metadata payload for a successful Plaid Link flow. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_connect" -- flutter analyze
melos exec --scope="ensemble_connect" -- flutter test
```

## Testing

A `test/` directory exists, but the current test file only contains an empty placeholder test.

## Related Packages / Modules

- `ensemble`: defines the `PlaidLinkManager` stub and the `openPlaidLink` action.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
