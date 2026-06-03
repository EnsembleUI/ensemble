# jsparser

`jsparser` is a Dart JavaScript parser that returns an AST from JavaScript source text.

## Overview

This is a utility package. The public library `package:jsparser/jsparser.dart` exports AST types and `ParseError`, and exposes the top-level `parsejs()` function implemented in `lib/jsparser.dart`.

## Features

- Parses JavaScript source into a `Program` AST.
- Supports parser options for filename, first line, noise handling, AST annotations, and expression parsing.
- Exports AST node types from `src/ast.dart`.
- Includes parser and lexer tests under `test/`.

## Installation / Setup

Use this package from inside the Melos workspace:

```bash
melos bootstrap
```

## Usage

```dart
import 'package:jsparser/jsparser.dart';

void main() {
  final ast = parsejs('var answer = 42;', filename: 'inline.js');
  print(ast.filename);
}
```

## Configuration

No additional configuration was found in this package.

## Platform Support

| Platform | Supported | Notes |
| -------- | --------: | ----- |
| Android | Unknown | Pure Dart package; no Android-specific evidence was found. |
| iOS | Unknown | Pure Dart package; no iOS-specific evidence was found. |
| Web | Unknown | Pure Dart package; no Web-specific evidence was found. |
| macOS | Unknown | Pure Dart package; no macOS-specific evidence was found. |
| Windows | Unknown | Pure Dart package; no Windows-specific evidence was found. |
| Linux | Unknown | Pure Dart package; no Linux-specific evidence was found. |

## Permissions

No runtime permissions were found in this package.

## API Reference

| API | Type | Description |
| --- | ---- | ----------- |
| `parsejs` | Function | Parses JavaScript source and returns a `Program` AST. |
| `Program` | Class | AST root exported from `src/ast.dart`. |
| `ParseError` | Class | Parser error exported from `src/lexer.dart`. |

## Development

```bash
melos bootstrap
melos exec --scope="jsparser" -- dart analyze
melos exec --scope="jsparser" -- dart test
```

## Testing

Tests are available under `test/`. Some compatibility tests use JavaScript fixtures under `test/testcases` and utilities under `test/util`.

## Related Packages / Modules

- `parsejs_null_safety`: the package variant under `packages/` exposes the same parser under a different package name.

## Notes for Contributors

- Keep examples in sync with source code.
- Update this README when public APIs, permissions, configuration, or platform support changes.
- Do not document unverified behavior.
