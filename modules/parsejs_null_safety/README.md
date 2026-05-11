# JSParser

**JSParser** is an upgraded Dart 3-compatible version of **ParseJS**. **ParseJS** is a JavaScript parser for Dart. It is well-tested and is reasonably efficient.
Original project : https://github.com/asgerf/parsejs.dart
This package is kept in the Melos workspace for parser compatibility work. Ensemble consumers generally depend on the published `parsejs_null_safety` package name from `packages/parsejs_null_safety`.

## Example Usage
```dart
import 'package:jsparser/jsparser.dart';
import 'dart:io';

void main() {
    new File('test.js').readAsString().then((String code) {
        Program ast = parsejs(code, filename: 'test.js');
        // Use the AST for something
    });
}
```

## Options

The `jsparser` function takes the following optional arguments:

- `filename`: An arbitrary string indicating where the source came from. For your convenience this will be available on `Node.filename` and on `ParseError.filename`.
- `firstLine`: The line number to associate with the first line of code. Default is 1. Useful if code was extracted from an HTML file, and you prefer absolute line numbers.
- `handleNoise`: If true, parser will try to ignore hash bangs and HTML comment tags surrounding the source code. Default is true.
- `annotate`: If true, parser will initialize `Node.parent`, `Scope.environment`, and `Name.scope`, to simplify subsequent AST analysis. Default is true.
- `parseAsExpression`: If true, the input will be parsed as an expression statement.


## Installation / Setup

From the repository root:

```bash
melos bootstrap
```

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android  | Unknown | Pure Dart parser; no platform-specific files were found. |
| iOS      | Unknown | Pure Dart parser; no platform-specific files were found. |
| Web      | Unknown | Pure Dart parser; no platform-specific files were found. |
| macOS    | Unknown | Pure Dart parser; no platform-specific files were found. |
| Windows  | Unknown | Pure Dart parser; no platform-specific files were found. |
| Linux    | Unknown | Pure Dart parser; no platform-specific files were found. |

## Permissions

No runtime permissions were found in this package.

## Development

```bash
melos bootstrap
melos exec --scope="jsparser" -- dart analyze
melos exec --scope="jsparser" -- dart test
```

## Testing

The package includes parser and lexer tests under `test/`.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.