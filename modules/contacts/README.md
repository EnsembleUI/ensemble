# ensemble_contacts

`ensemble_contacts` provides an Ensemble contact manager implementation backed by `fast_contacts`.

## Overview

This is an optional native-capability module. `ContactManagerImpl` implements the core `ContactManager` contract and reads contacts after checking contact permission through `fast_contacts`.

## Features

- Requests contact permission through `FastContacts.requestPermission()`.
- Returns contact names, phone numbers, and email addresses as Ensemble contact models.
- Implements the contact manager stub from the core runtime.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified entry point is `ContactManagerImpl` in `lib/contact_manager.dart`. No standalone Dart or Ensemble YAML example was found in this package. Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

No additional configuration was found in this package. Host apps must add the platform privacy strings or manifest permissions required by their contact-access target platforms.

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

The Dart source requests contact permission through `FastContacts.requestPermission()`. Platform permission names and usage descriptions are not declared in this package and must be supplied by the host app.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `ContactManagerImpl` | Service | Implements Ensemble's contact manager by reading contacts through `fast_contacts`. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_contacts" -- flutter analyze
melos exec --scope="ensemble_contacts" -- flutter test
```

## Testing

A `test/` directory exists, but the current test file only contains an empty placeholder test.

## Related Packages / Modules

- `ensemble`: defines the `ContactManager` contract implemented by this package.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
