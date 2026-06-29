# ensemble_dropdown

`ensemble_dropdown` provides dropdown widgets and styling data classes used by Ensemble Flutter UI code.

## Overview

This is a Flutter utility package. The public barrel `lib/ensemble_dropdown.dart` exports `src/ensemble_dropdown.dart` and `src/ensemble_dropdown_data.dart`, including `EnsembleDropdown`, `DropdownButtonFormField2`, and style/configuration classes.

## Features

- Provides `EnsembleDropdown<T>` for configurable dropdown menus.
- Provides `DropdownButtonFormField2<T>` for form integration.
- Provides style data classes for buttons, icons, menus, menu items, and searchable dropdowns.
- Includes widget tests under `test/`.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified public import is:

```dart
import 'package:ensemble_dropdown/ensemble_dropdown.dart';
```

A minimal usage pattern is to build an `EnsembleDropdown` with Flutter `DropdownMenuItem` values. See `test/ensemble_dropdown_test.dart` for source-verified widget construction examples.

## Configuration

No additional configuration was found in this package.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Unknown | No Android-specific package files were found. |
| iOS | Unknown | No iOS-specific package files were found. |
| Web | Unknown | No Web-specific package files were found. |
| macOS | Unknown | No macOS-specific package files were found. |
| Windows | Unknown | No Windows-specific package files were found. |
| Linux | Unknown | No Linux-specific package files were found. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `EnsembleDropdown<T>` | Widget | Configurable dropdown widget. |
| `EnsembleDropdownState<T>` | State | State object for `EnsembleDropdown`. |
| `DropdownButtonFormField2<T>` | Widget | Form-field wrapper for dropdown input. |
| `ButtonStyleData` | Class | Button style configuration. |
| `IconStyleData` | Class | Dropdown icon style configuration. |
| `DropdownStyleData` | Class | Dropdown menu style configuration. |
| `MenuItemStyleData` | Class | Dropdown menu item style configuration. |
| `DropdownSearchData<T>` | Class | Search configuration for dropdowns. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_dropdown" -- flutter analyze
melos exec --scope="ensemble_dropdown" -- flutter test
```

## Testing

Package-specific widget tests are in `test/ensemble_dropdown_test.dart`.

## Related Packages / Modules

No related packages or modules were verified from imports, dependencies, examples, or tests.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
