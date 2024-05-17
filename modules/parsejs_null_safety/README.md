# JSParser

**JSParser** is an updgraded version, for Dart 2.4 and above, of **ParseJS**. **ParseJS** is a JavaScript parser for Dart. It is well-tested and is reasonably efficient.
Original project : https://github.com/asgerf/parsejs.dart
This project is intended to migrate it to dart 2.4 or above

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


## To run test cases 
1. Open terminal and cd to parsejs.dart/test/util directory
2. Do `npm install` 
3. CD to parsejs.dart/test/ director and run `./runtest`