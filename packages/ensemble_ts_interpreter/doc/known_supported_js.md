# Known Supported JavaScript

`ensemble_ts_interpreter` targets practical JavaScript ES5 for app logic inside Ensemble and Flutter apps. Some ES6+ conveniences already work, but ES5 is the compatibility baseline.

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

## ES6+ Conveniences That May Work

These features are available today where tests cover them, but they are not the baseline compatibility contract yet:

- Arrow functions.
- `Map` and `Set` globals.
- `Promise`, `queueMicrotask`, and promise-style helpers.
- Some modern array and string helpers such as `includes`, `flat`, `flatMap`, `startsWith`, and `endsWith`.

Treat these as supported conveniences, not full ES6 conformance.

## Known Unsupported Or Partial Areas

Do not rely on these areas for production app logic yet:

- `let`, `const`, block scoping, temporal dead zone behavior, and strict mode conformance.
- ES6 classes, modules, imports, exports, destructuring, spread/rest, template literals, generators, and async/await.
- Direct `eval` scope behavior.
- Full Test262 conformance, especially edge cases around property descriptors, coercion, `Date`, `RegExp`, strict mode, and host objects.
- Browser-specific APIs beyond the globals provided by Ensemble.

## Compatibility Guidance

For the most reliable app code:

- Prefer ES5-style functions and `var`.
- Use `Object.*`, array callbacks, and JSON APIs normally, but keep logic app-focused rather than engine-conformance-heavy.
- Treat Dart `null` at the public boundary as the practical representation for JavaScript `null`/`undefined`.
- Add focused interpreter tests when introducing new JavaScript patterns that app screens depend on.

## Security And Resource Notes

- `JSON.stringify` rejects circular object/list graphs instead of recursing indefinitely.
- Sparse arrays are supported for practical app use, but extremely large index expansion is capped to avoid accidental memory exhaustion.
- Treat JS code as app logic, not as an isolation boundary for hostile code. Host capabilities exposed in the context, such as Dart callbacks or globals like `fetch`, are callable from JS.
