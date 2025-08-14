[![Pub](https://img.shields.io/pub/v/ensemble_ts_interpreter.svg)](https://pub.dartlang.org/packages/ensemble_ts_interpreter)
[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.5+-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

# Ensemble TS Interpreter

A JavaScript (ES5) interpreter written entirely in Dart for Flutter applications. Execute JavaScript code inline within your Dart/Flutter app without external engines. Features include primitive types, arrays, maps, function declarations, and extensible context objects.

## ✨ Features

- **Pure Dart Implementation**: No external JavaScript engines or bridges required
- **ES5 Compatibility**: Full support for JavaScript ES5 syntax and features
- **High Performance**: Runs in the same process as your Dart/Flutter code
- **Extensible Context**: Pass JSON objects or custom Dart objects with the `Invokable` mixin
- **Primitive Types**: Support for strings, numbers, arrays, maps, dates, and more
- **Function Support**: Declare and execute JavaScript functions
- **Memory Efficient**: No memory issues or bridge overhead like React Native

## 🚀 Quick Start

### Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  ensemble_ts_interpreter: ^1.0.3
```

Then run:
```bash
flutter pub get
```

### Basic Usage

```dart
import 'package:ensemble_ts_interpreter/ensemble_ts_interpreter.dart';

void main() {
  // Create a context with data
  Map<String, dynamic> context = {
    'items': ['one', 'two', 'three'],
    'count': 0
  };

  // JavaScript code to execute
  String code = """
    var filtered = items.filter(function(item) {
      return item != 'two';
    });
    
    count = filtered.length;
    console.log('Filtered items:', filtered);
  """;

  // Execute the JavaScript code
  JSInterpreter.fromCode(code, context).evaluate();
  
  print('Count: ${context['count']}'); // Output: Count: 2
}
```

## 🔧 Core Concepts

### Context Object

The context object is the key to the interpreter. You can pass:

- **JSON Objects**: Simple key-value pairs
- **Custom Dart Objects**: Enhanced with the `Invokable` mixin for method calls
- **Mixed Data**: Combine both approaches for complex scenarios

### JavaScript Support

- ✅ **Primitive Types**: String, Number, Boolean, null, undefined
- ✅ **Arrays**: All standard array methods (filter, map, reduce, etc.)
- ✅ **Objects/Maps**: Property access, method calls
- ✅ **Functions**: Declaration, execution, and closures
- ✅ **Control Flow**: if/else, loops, switch statements
- ✅ **Date Objects**: Full date manipulation support

### Limitations

- ❌ **Classes**: No class declaration or instantiation
- ❌ **Modules**: No import/require statements
- ❌ **ES6+ Features**: Limited to ES5 syntax

## 📚 Examples

### Filter and Transform Arrays

```dart
Map<String, dynamic> context = {
  'users': [
    {'name': 'Alice', 'age': 25, 'role': 'developer'},
    {'name': 'Bob', 'age': 30, 'role': 'designer'},
    {'name': 'Charlie', 'age': 28, 'role': 'developer'}
  ]
};

String code = """
  var developers = users.filter(function(user) {
    return user.role === 'developer';
  });
  
  var names = developers.map(function(user) {
    return user.name.toUpperCase();
  });
  
  var totalAge = developers.reduce(function(sum, user) {
    return sum + user.age;
  }, 0);
  
  var averageAge = totalAge / developers.length;
""";

JSInterpreter.fromCode(code, context).evaluate();

print('Developers: ${context['names']}'); // [ALICE, CHARLIE]
print('Average age: ${context['averageAge']}'); // 26.5
```

### String Manipulation

```dart
Map<String, dynamic> context = {
  'text': '  Hello World  ',
  'words': ['hello', 'world', 'dart', 'flutter']
};

String code = """
  var trimmed = text.trim();
  var upper = trimmed.toUpperCase();
  var lower = trimmed.toLowerCase();
  
  var joined = words.join('-');
  var reversed = words.reverse();
  var includes = words.includes('dart');
""";

JSInterpreter.fromCode(code, context).evaluate();

print('Trimmed: "${context['trimmed']}"'); // "Hello World"
print('Joined: ${context['joined']}'); // "hello-world-dart-flutter"
print('Includes Dart: ${context['includes']}'); // true
```

### Function Declaration and Execution

```dart
Map<String, dynamic> context = {
  'numbers': [1, 2, 3, 4, 5],
  'multiplier': 2
};

String code = """
  function doubleArray(arr, factor) {
    return arr.map(function(num) {
      return num * factor;
    });
  }
  
  function calculateSum(arr) {
    return arr.reduce(function(sum, num) {
      return sum + num;
    }, 0);
  }
  
  var doubled = doubleArray(numbers, multiplier);
  var sum = calculateSum(doubled);
  var average = sum / doubled.length;
""";

JSInterpreter.fromCode(code, context).evaluate();

print('Doubled: ${context['doubled']}'); // [2, 4, 6, 8, 10]
print('Sum: ${context['sum']}'); // 30
print('Average: ${context['average']}'); // 6.0
```

### Date Manipulation

```dart
Map<String, dynamic> context = {
  'currentDate': DateTime.now()
};

String code = """
  var date = new Date();
  var year = date.getFullYear();
  var month = date.getMonth() + 1;
  var day = date.getDate();
  
  var tomorrow = new Date();
  tomorrow.setDate(tomorrow.getDate() + 1);
  
  var formatted = year + '-' + month + '-' + day;
""";

JSInterpreter.fromCode(code, context).evaluate();

print('Formatted: ${context['formatted']}'); // Current date in YYYY-M-D format
```

## 🔌 Advanced Usage

### Custom Invokable Objects

Create custom Dart objects that can be called from JavaScript:

```dart
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Calculator extends Invokable {
  int add(int a, int b) => a + b;
  int multiply(int a, int b) => a * b;
  double divide(int a, int b) => a / b;
}

void main() {
  var calculator = Calculator();
  
  Map<String, dynamic> context = {
    'calc': calculator,
    'x': 10,
    'y': 5
  };

  String code = """
    var sum = calc.add(x, y);
    var product = calc.multiply(x, y);
    var quotient = calc.divide(x, y);
  """;

  JSInterpreter.fromCode(code, context).evaluate();
  
  print('Sum: ${context['sum']}'); // 15
  print('Product: ${context['product']}'); // 50
  print('Quotient: ${context['quotient']}'); // 2.0
}
```

### Error Handling

```dart
try {
  String code = """
    var result = undefinedFunction();
    var invalid = 10 / 0;
  """;
  
  JSInterpreter.fromCode(code, context).evaluate();
} catch (e) {
  if (e is JSInterpreterException) {
    print('JavaScript Error: ${e.message}');
    print('Line: ${e.line}, Column: ${e.column}');
  } else {
    print('Dart Error: $e');
  }
}
```

## 🧪 Testing

Run the comprehensive test suite:

```bash
flutter test
```

The test suite includes examples for:
- Array operations
- String manipulation
- Function declarations
- Date handling
- Error scenarios
- Complex nested operations

## 📱 Platform Support

- ✅ **Android**: Full support
- ✅ **iOS**: Full support
- ✅ **Web**: Full support
- ✅ **Desktop**: Full support

## 🤝 Contributing

We welcome contributions! Please feel free to:
- Report bugs and issues
- Suggest new features
- Submit pull requests
- Improve documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Part of the Ensemble UI ecosystem
- Built for the Flutter community

---

**Built with ❤️ for the Flutter community**

