# Known Supported JavaScript

`ensemble_ts_interpreter` targets practical JavaScript ES5 for app logic inside Ensemble and Flutter apps. A small ES6+ subset is also supported for common developer ergonomics, but ES5 remains the compatibility baseline.

## Supported Baseline

The interpreter supports common ES5 app logic:

- Variables with `var`, function declarations, function expressions, closures, and immediately invoked functions.
- `this` binding for method calls, constructor calls with `new`, prototypes, and practical `arguments`.
- Control flow including `if`, `for`, `for...in`, `while`, `do...while`, `switch`, labels, `break`, `continue`, `try`, `catch`, and `finally`.
- Operators including loose/strict equality, logical operators, bitwise operators, `void`, `typeof`, `in`, `instanceof`, and unsigned right shift.
- Object literals, array literals, getters, setters, property descriptors, prototypes, `delete`, sparse arrays, and JSON parsing/stringifying.
- Core globals and built-ins used by Ensemble apps, including `Object`, `Array`, `String`, `Number`, `Math`, `Date`, `RegExp`, `JSON`, `Map`, `Set`, `Promise`, and `console`.

This baseline is covered by package tests, including app-style snippets and focused compatibility cases for control flow, operators, functions, object descriptors, prototypes, arrays, sparse arrays, JSON, and Dart/Ensemble interop. It is intended to be reliable for app code, but it is not a claim of full Test262 conformance.

## Practical Object And Array Behavior

The runtime uses Dart `Map`, `List`, and `Invokable` values at the public boundary, with internal helpers for JavaScript-like behavior.

- `Object.keys`, `Object.values`, `Object.entries`, `Object.create`, `Object.assign`, `Object.defineProperty`, `Object.getOwnPropertyDescriptor`, and `Object.getPrototypeOf` are supported for practical ES5 object use.
- `hasOwnProperty`, `propertyIsEnumerable`, `in`, and `for...in` use JavaScript-style property presence, enumerability, and prototype lookup.
- Sparse array holes are preserved for `delete`, skipped by callback methods, and serialized as `null` by `JSON.stringify`.
- `Function.prototype.call`, `apply`, and `bind` work for interpreter functions and compatible Dart callbacks.

## Supported ES6 Conveniences

These features are covered by focused package tests:

- Arrow functions, including the common single-parameter form without parentheses.
- `let` and `const` declarations with practical block scoping.
- `const` reassignment errors.
- Read-before-initialization errors for lexical declarations.
- Per-iteration `let` bindings for `for` loops.
- Practical `for...of` loops over arrays/lists, strings, `Map`, and `Set`.
- Destructuring in practical `for...of` declarations and assignment targets.
- Template literals with `${...}` interpolation and practical tagged-template calls.
- Object and array destructuring declarations, defaults, object rest properties, destructuring parameters, and practical destructuring assignment.
- Object property shorthand, enhanced object methods, and computed property names.
- Default parameters and rest parameters for normal functions and arrow functions.
- Spread in array literals, function calls, and object literals.
- `Array.from`, including arrays/lists, strings, `Map`, `Set`, and array-like objects, plus `Array.of` and `new Array(length)`.
- `Object.fromEntries`, `Object.hasOwn`, and `Object.getOwnPropertyNames`.
- Optional chaining with `?.`, including property access, index access, and optional calls.
- Nullish coalescing with `??`, falling back only for practical null/undefined values.
- `Map` and `Set` globals.
- `Symbol` values as computed object keys.
- `Promise`, `Promise.all`, `Promise.allSettled`, `Promise.race`, `Promise.any`, `Promise.prototype.finally`, `queueMicrotask`, and promise-style helpers.
- Practical `async` functions and async arrows with `await` for `Promise`, Dart `Future`, and plain values.
- Some modern array and string helpers such as `includes`, `flat`, `flatMap`, `startsWith`, and `endsWith`.

Treat these as supported conveniences, not full ES6 conformance.

## Known Unsupported Or Partial Areas

Do not rely on these areas for production app logic yet:

- Strict mode conformance.
- ES6 classes, modules, imports, exports, and generators.
- Full tagged-template edge cases such as `strings.raw` identity/caching semantics.
- Full destructuring edge-case coverage beyond practical declaration, parameter, assignment, and `for...of` patterns.
- Full async/await coverage in every statement/expression position; supported app patterns include awaited variable initializers, awaited returns, and simple expressions around awaited values.
- Direct `eval` scope behavior.
- Full Test262 conformance, especially edge cases around property descriptors, coercion, `Date`, `RegExp`, strict mode, and host objects.
- Browser-specific APIs beyond the globals provided by Ensemble.

## Compatibility Guidance

For the most reliable app code:

- Prefer ES5-style functions and `var` for maximum portability; use the documented ES6 subset where tests cover your app pattern.
- Use `Object.*`, array callbacks, and JSON APIs normally, but keep logic app-focused rather than engine-conformance-heavy.
- Treat Dart `null` at the public boundary as the practical representation for JavaScript `null`/`undefined`.
- Add focused interpreter tests when introducing new JavaScript patterns that app screens depend on.

## Security And Resource Notes

- `JSON.stringify` rejects circular object/list graphs instead of recursing indefinitely.
- Sparse arrays are supported for practical app use, but extremely large index expansion is capped to avoid accidental memory exhaustion.
- Treat JS code as app logic, not as an isolation boundary for hostile code. Host capabilities exposed in the context, such as Dart callbacks or globals like `fetch`, are callable from JS.
