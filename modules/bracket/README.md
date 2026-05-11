# ensemble_bracket

`ensemble_bracket` provides an Ensemble widget for rendering elimination-style tournament brackets from templated round and match data.

## Overview

This is an optional Ensemble widget module. `EnsembleBracketImpl` extends `EnsembleWidget` and implements the core `EnsembleBracket` stub, allowing the runtime to render bracket rounds, tabs, connecting lines, and match templates from Ensemble data.

## Features

- Renders round data using an Ensemble item template.
- Supports match item templates with configurable row height.
- Exposes line style configuration for bracket connectors.
- Exposes tab style configuration for round navigation.

## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

The package is intended for use inside the Ensemble monorepo and by host apps that register the `EnsembleBracketImpl` implementation.

## Usage

The widget controller accepts `items`, `lineStyles`, and `tabStyles` setters. A safe complete YAML example was not found in this package, so no YAML syntax is documented here beyond the verified property names.

Usage examples are not currently available in this package. See the source files under `lib/` for implementation details.

## Configuration

No additional configuration was found in this package.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Flutter widget package; no platform folder or plugin declaration was found. |
| iOS      | Unknown | Flutter widget package; no platform folder or plugin declaration was found. |
| Web      | Unknown | Not verified from source. |
| macOS    | Unknown | Not verified from source. |
| Windows  | Unknown | Not verified from source. |
| Linux    | Unknown | Not verified from source. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `EnsembleBracketImpl` | Widget | Ensemble widget implementation for bracket rendering. |
| `BracketController` | Controller | Stores bracket items, line styles, and tab styles. |
| `RoundTemplate` | Model | Describes a round template and its match template. |
| `MatchTemplate` | Model | Describes match data, template content, and match height. |

## Development

```bash
melos bootstrap
melos exec --scope="ensemble_bracket" -- flutter analyze
melos exec --scope="ensemble_bracket" -- flutter test
```

## Testing

The package includes `test/ensemble_bracket_test.dart`.

## Related Packages / Modules

- `ensemble` provides `EnsembleWidget`, templating, scope, and the bracket stub interface.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.