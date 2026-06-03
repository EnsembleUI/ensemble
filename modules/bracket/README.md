# ensemble_bracket

`ensemble_bracket` implements an Ensemble `Bracket` widget for rendering elimination-style tournament brackets.

## Overview

This is an optional Ensemble widget module. The package exports `lib/src/bracket.dart`, where `EnsembleBracketImpl` implements the `EnsembleBracket` contract and `BracketController` manages bracket templates and data.

## Features

- Implements the Ensemble widget type `Bracket`.
- Supports round and match templates through `RoundTemplate` and `MatchTemplate`.
- Provides bracket rendering widgets and a custom painter for bracket connectors.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

The verified public import is:

```dart
import 'package:ensemble_bracket/ensemble_bracket.dart';
```

A complete Ensemble YAML example was not found in this package, so no YAML data shape is documented here.

## Configuration

No additional configuration was found in this package.

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
| `EnsembleBracketImpl` | Widget | Ensemble widget implementation for the `Bracket` type. |
| `BracketController` | Controller | Holds bracket properties and template configuration. |
| `RoundTemplate` | Template | Template model for rounds. |
| `MatchTemplate` | Template | Template model for matches. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_bracket" -- flutter analyze
melos exec --scope="ensemble_bracket" -- flutter test
```

## Testing

A `test/` directory exists, but the current test file only contains an empty placeholder test.

## Related Packages / Modules

- `ensemble`: defines the `EnsembleBracket` contract resolved by the core widget registry.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
