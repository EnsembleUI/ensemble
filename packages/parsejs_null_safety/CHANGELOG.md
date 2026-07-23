## 2.1.0 (2026-07-01)
- Added parser support for ES6 syntax used by Ensemble: `let`, `const`, `for...of`, untagged template literals, default parameters, rest parameters, and spread in arrays/calls.
- Added parser support for optional chaining (`?.`) and nullish coalescing (`??`).
- Added parser and AST support for single-parameter arrow functions, object/array binding patterns, object shorthand properties, enhanced object methods, and computed property names.
- Added parser and AST support for practical `async` functions, async arrows, and `await` expressions.
- Added parser support for destructuring parameters, destructuring assignment targets, and object spread.
- Added parser and AST support for tagged template expressions.
- Added parser support for destructuring defaults, object rest binding properties, and destructuring in `for...of` declarations.
- Added AST nodes and visitor hooks for declaration kinds, templates, spread, default parameters, and rest parameters.

## 2.0.4 (2025-08-13)
- Fixes for Dart 3.5+ compatibility

## 2.0.3 (2025-08-13)
- Updated for Dart 3.5+ compatibility
- Added null safety support
- Improved pubspec.yaml for pub.dev publication
- Updated documentation and examples

## 2.0.2 (2024-12-19)
- Updated for Dart 3.5+ compatibility
- Added null safety support
- Improved pubspec.yaml for pub.dev publication
- Updated documentation and examples

## 2.0.1 (2024-12-19)
- Amended Pub analysis suggestions

## 2.0.0 (2024-12-19)
- Updated for Dart 3.5+ with null safety

## 1.2.0 (2017-05-06)

- Added an option to parse the input as an expression.

## 1.1.0 (2015-06-01)

- Added visitor with one argument.

## 1.0.0 - 1.0.3

- Initial version with some bugfixes releases.
