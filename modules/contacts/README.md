# ensemble_contacts

`ensemble_contacts` implements Ensemble's contacts manager stub using Flutter contacts plugins.

## Overview

This is a native module for Ensemble apps that need to read device contacts. `ContactManagerImpl` requests read-only contact permission, fetches contacts with `fast_contacts`, maps them into Ensemble contact models, and can fetch contact photos by ID.

## Features

- Requests read-only contact permission through `flutter_contacts`.
- Fetches all contacts through `fast_contacts`.
- Maps names, phone numbers, email addresses, and organizations into Ensemble contact models.
- Fetches contact images through `FastContacts.getContactImage`.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

Host apps must provide the platform permission strings/manifests required by the contact plugins before enabling this module.

## Usage

The manager implementation is consumed through Ensemble's contacts stub:

```dart
import 'package:ensemble_contacts/contact_manager.dart';

final manager = ContactManagerImpl();
final hasPermission = await manager.requestPermission();
```

No verified Ensemble YAML example was found in this package.

## Configuration

No package-local configuration keys were found.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Uses contacts plugins; no package-level Android manifest was found. |
| iOS      | Unknown | Uses contacts plugins; no package-level iOS plist was found. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

The source requests read-only contact access through `FlutterContacts.requestPermission(readonly: true)`. Platform permission declarations were not found in this package, so host apps must configure the relevant contact permissions and usage descriptions.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `ContactManagerImpl` | Class | Ensemble contacts manager implementation. |
| `getPhoneContacts` | Method | Requests permission, fetches contacts, and returns mapped Ensemble contacts. |
| `getContactPhoto` | Method | Fetches a contact image by contact ID. |
| `requestPermission` | Method | Requests read-only contact permission. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_contacts" -- flutter analyze
melos exec --scope="ensemble_contacts" -- flutter test
```

## Testing

The package includes `test/ensemble_contacts_test.dart`.

## Related Packages / Modules

- `ensemble` provides the contacts manager stub and contact models.
- `fast_contacts` and `flutter_contacts` provide native contact access.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
