# ensemble_bracket

`ensemble_bracket` implements an Ensemble `Bracket` widget for rendering elimination-style tournament brackets.

## Overview

This is an optional Ensemble widget module. The package exports `lib/src/bracket.dart`, where `EnsembleBracketImpl` implements the `EnsembleBracket` contract and `BracketController` manages bracket templates and data.

## Features

- Implements the Ensemble widget type `Bracket`.
- Supports round and match templates through `RoundTemplate` and `MatchTemplate`.
- Provides bracket rendering widgets and a custom painter for bracket connectors.
- Full TV/Android TV D-pad navigation support with customizable focus styling.

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

### Basic YAML Example (Mobile/Web)

```yaml
Bracket:
    id: bracket
    styles:
        borderColor: transparent
        borderWidth: 2
        lineStyles:
            color: 0xff404040
            width: 2
        tabStyles:
            backgroundColor: 0xFF232323
            selectedBackgroundColor: 0xFF00C300
            textStyle:
                color: 0xFFB3B3B3
            selectedTextStyle:
                color: black
            borderRadius: 8

    items:
        data: ${bracketData}
        name: round
        title: ${round.title}
        item-template:
            data: ${round.matches}
            name: match
            height: 100
            template:
                MatchCard:
                    inputs:
                        match: ${match}
```

### TV YAML Example (Android TV / D-pad)

```yaml
Bracket:
    id: bracket
    styles:
        borderColor: transparent
        borderWidth: 2
        tvOptions:
            row: 1 # TV: Tab row, matches start at row+1
        lineStyles:
            color: 0xff404040
            width: 2
        tabStyles:
            backgroundColor: 0xFF232323
            selectedBackgroundColor: 0xFF00C300
            textStyle:
                color: 0xFFB3B3B3
            selectedTextStyle:
                color: black
            borderRadius: 8
            focusBorderRadius: 12 # TV: Focus indicator radius

    items:
        data: ${bracketData}
        name: round
        title: ${round.title}
        item-template:
            data: ${round.matches}
            name: match
            height: 100
            template:
                MatchCard:
                    inputs:
                        match: ${match}
```

## Configuration

### Bracket Properties

| Property      | Type   | TV  | Description                     |
| ------------- | ------ | :-: | ------------------------------- |
| `borderColor` | Color  |     | Border color around match cards |
| `borderWidth` | Number |     | Border width around match cards |

### Line Styles (`lineStyles`)

| Property | Type   | TV  | Description                      |
| -------- | ------ | :-: | -------------------------------- |
| `color`  | Color  |     | Color of bracket connector lines |
| `width`  | Number |     | Width of bracket connector lines |

### Tab Styles (`tabStyles`)

| Property                   | Type       | TV  | Description                                   |
| -------------------------- | ---------- | :-: | --------------------------------------------- |
| `backgroundColor`          | Color      |     | Background color of unselected tabs           |
| `selectedBackgroundColor`  | Color      |     | Background color of selected tab              |
| `textStyle`                | TextStyle  |     | Text style for unselected tabs                |
| `selectedTextStyle`        | TextStyle  |     | Text style for selected tab                   |
| `borderRadius`             | Number     |     | Border radius of tabs                         |
| `borderColor`              | Color      |     | Border color of tabs                          |
| `borderWidth`              | Number     |     | Border width of tabs                          |
| `padding`                  | EdgeInsets |     | Padding inside tabs                           |
| `gap`                      | Number     |     | Gap between tabs (default: 12)                |
| `focusBorderColor`               | Color      | ✅  | Focus border color when navigating with D-pad |
| `focusBorderWidth`         | Number     | ✅  | Focus border width (default: 2.0)             |
| `focusBorderRadius`        | Number     | ✅  | Focus border radius (default: 8.0)            |
| `focusBackgroundColor`     | Color      | ✅  | Background color when focused                 |
| `focusTextStyle`           | TextStyle  | ✅  | Text style when focused                       |
| `focusAnimationDurationMs` | Number     | ✅  | Focus animation duration in milliseconds      |

### TV Options (`tvOptions`)

| Property | Type   | TV  | Description                                                            |
| -------- | ------ | :-: | ---------------------------------------------------------------------- |
| `row`    | Number | ✅  | TV navigation row offset. Tabs are at this row, matches start at row+1 |

---

## TV D-pad Navigation

> **Note**: This section only applies to Android TV / TV devices with D-pad remote control.

### Focus Styling Priority Chain

The bracket widget follows the same focus styling priority as other Ensemble widgets:

1. **tabStyles focus properties** (e.g., `focusBorderColor`, `focusBorderWidth`)
2. **Theme** (`EnsembleThemeExtension.tvFocusTheme`)
3. **Provider** (`TVFocusProviderScope`)
4. **tabStyles regular properties** (e.g., `borderColor`, `borderWidth`)
5. **Default values** (focusBorderWidth: 2.0, focusBorderRadius: 8.0)

### Navigation Behavior

The bracket widget provides full TV D-pad navigation:

- **LEFT/RIGHT** arrows navigate between rounds (columns)
- **UP/DOWN** arrows navigate between matches within a round
- Focus automatically transfers to the corresponding row when changing rounds
- Row clamping ensures focus stays within available matches (e.g., 8 matches in Round of 16 → 4 matches in Quarter Finals)

### Match Card tvOptions

Match cards within the bracket should include `tvOptions` for focus styling:

```yaml
MatchCard:
    body:
        Column:
            styles:
                tvOptions:
                    row: 0 # Required for box_wrapper focus styling (actual row is set by bracket)
                    backgroundColor: 0xff303030 # Background when focused
```

Note: The `row` value is overridden by the bracket for navigation ordering, but must be present for box_wrapper to apply focus styling.

## Platform Support

| Platform | Supported | Notes                                |
| -------- | --------: | ------------------------------------ |
| Android  |        ✅ | Full support including Android TV    |
| iOS      |        ✅ | Full support                         |
| Web      |        ✅ | Full support                         |
| macOS    |        ✅ | Full support                         |
| Windows  |        ✅ | Full support                         |
| Linux    |         - | Not listed in pubspec.yaml platforms |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API                   | Type       | Description                                               |
| --------------------- | ---------- | --------------------------------------------------------- |
| `EnsembleBracketImpl` | Widget     | Ensemble widget implementation for the `Bracket` type.    |
| `BracketController`   | Controller | Holds bracket properties and template configuration.      |
| `RoundTemplate`       | Template   | Template model for rounds.                                |
| `MatchTemplate`       | Template   | Template model for matches.                               |
| `RoundData`           | Data       | Resolved round data with title, matches, and local scope. |

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
