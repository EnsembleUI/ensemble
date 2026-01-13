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
