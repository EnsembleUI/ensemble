## [1.3.0] - ES6 Runtime Support

* Added practical ES6 support for `let`, `const`, block scoping, const reassignment errors, and read-before-initialization errors.
* Added template literal evaluation, default parameters, rest parameters, and spread in array literals and function calls.
* Added practical `for...of` loops and per-iteration `let`/`const` bindings so closures capture the expected iteration value.
* Added practical optional chaining (`?.`) and nullish coalescing (`??`) support for app logic.
* Added common ES6 syntax support for single-parameter arrow functions, object/array destructuring declarations, object shorthand properties, enhanced object methods, computed property names, and `Symbol` keys.
* Verified practical `Promise.then(...)` callbacks with arrow functions.
* Added practical `async`/`await` support for async functions and async arrows that await `Promise`, Dart `Future`, and plain values.
* Added practical support for destructuring parameters, destructuring assignment, object spread, `Array.from`, `Array.of`, `new Array(length)`, `Promise.all`, and `Promise.allSettled`.
* Added practical tagged template support for app-level formatting helpers such as currency/string tag functions.
* Added final ES6 convenience coverage for `Array.from` collections/array-like objects, `Object.fromEntries`, `Object.hasOwn`, `Object.getOwnPropertyNames`, `Promise.race`, `Promise.any`, `Promise.prototype.finally`, destructuring defaults/rest, and `for...of` destructuring.
* Added practical `Array.prototype.findLast` and `findLastIndex` support.
* Fixed method references such as `fetchData().then(console.log)` by exposing invokable methods as readable callback values.
* Fixed out-of-range array reads to return JavaScript `undefined` instead of Dart `null`.
* Added focused ES6 compatibility tests while preserving the ES5 runtime test gate and existing ES6 conveniences.
* Updated parser dependency to `parsejs_null_safety` 2.1.0 for the required ES6 AST support.

## [1.2.0] - Practical ES5 Runtime Stability

* Added a documented practical ES5 compatibility baseline with focused regression tests.
* Improved interpreter semantics for ES5 control flow, operators, functions, `this`, constructors, `arguments`, object descriptors, accessors, prototypes, sparse arrays, and JSON behavior.
* Added practical support for `Object.create`, `Object.assign`, `Object.getPrototypeOf`, `Object.defineProperty`, `Object.getOwnPropertyDescriptor`, `hasOwnProperty`, `propertyIsEnumerable`, and `Function.prototype.call/apply/bind`.
* Hardened array and string behavior around sparse arrays, holes, negative indexes, optional bounds, string indexes, and JS-style numeric parsing/coercion.
* Preserved existing Ensemble interop and selected ES6+ conveniences such as arrow functions, `Map`, `Set`, and `Promise`.
* Added runtime safety guards for circular `JSON.stringify` inputs and extremely large sparse-array expansion.
* Added package-level performance smoke coverage and made primitive date tests timezone-stable.
* Added `doc/known_supported_js.md` to describe supported JS, ES6+ conveniences, and known unsupported areas.

## [1.0.7] - Bug Fixes

* Fixed issue where Error objects were not being properly unwrapped in catch clauses.

## [1.0.6] - Allow Global code to overwrite imported functions

* Allow Global code to overwrite imported functions, aligning with JavaScript behavior

## [1.0.5] - Add invokable collections and enhance JSON handling

* Introduced JSMap and JSSet classes for JavaScript-like map and set functionalities, including methods for manipulation and retrieval.
* Added JSResponse and Fetch classes to handle HTTP requests and responses, integrating with promises for asynchronous operations.
* Enhanced JSON class methods to support replacer and reviver functions for stringify and parse operations.
* Implemented additional methods in StaticObject and InvokableObject for object manipulation.
* Added static utility classes for Array, Number, String, and Performance to provide JavaScript-like functionalities in Dart.

## [1.0.4] - Bug Fixes

* Updated Date class to support cloning from Date instances and improved fallback parsing logic.
* Enhanced Console class with multiple logging methods (log, info, warn, error, debug, trace) and argument normalization.
* Introduced private methods for argument formatting and emission to streamline logging functionality.
* Improved context handling in JSInterpreter for better scope resolution and function declaration hoisting.

## [1.0.3] - Moved to packages directory

## [1.0.2] - Package Publication and Code Quality Improvements

* Package prepared for pub.dev publication
* Enhanced documentation and examples
* Improved package metadata and structure
* Updated dependencies and SDK constraints
* Fixed analysis warnings: removed unused imports and variables
* Reduced analysis issues from 80 to 70

## [1.0.0] - Package Publication

* Package prepared for pub.dev publication
* Enhanced documentation and examples
* Improved package metadata and structure
* Updated dependencies and SDK constraints

## [1.0.0+1] - Initial Package

* Initial Package
* Support for javascript (ES5) syntax
* Supports most of the Javascript primitive types such as string, number, arrays and maps.
* Supports declaring javascript functions and calling them
* Does not support declaring classes or interfaces or instantiating them.
* Does not support import or require
