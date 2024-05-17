import 'dart:math' as math;

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class InvokableMath extends Object with Invokable, MethodExecutor {
  InvokableMath();

  @override
  Map<String, Function> getters() {
    return {};
  }

  dynamic _toNum(dynamic value) {
    if (value == null) {
      return 0; // Mimic JavaScript coercion of null to 0
    } else if (value is num) {
      return value;
    } else if (value is String) {
      return num.tryParse(
          value); // Returns null if parsing fails, which will be filtered out
    }
    return null; // Non-convertible values return null, indicating an inability to coerce
  }

  @override
  Map<String, Function> methods() {
    return {
      'floor': (dynamic n) => _toNum(n)?.floor(),
      'abs': (dynamic n) => _toNum(n)?.abs(),
      'ceil': (dynamic n) => _toNum(n)?.ceil(),
      'round': (dynamic n) => _toNum(n)?.round(),
      'trunc': (dynamic n) => _toNum(n)?.truncate(),
      'log': (dynamic n) => math.log(_toNum(n) ?? 1),
      // Default to 1 to prevent log(0)
      'pow': (dynamic x, dynamic y) => math.pow(_toNum(x) ?? 0, _toNum(y) ?? 0),
      'acos': (dynamic n) => math.acos(_toNum(n) ?? 1),
      'asin': (dynamic n) => math.asin(_toNum(n) ?? 0),
      'atan': (dynamic x) => math.atan(_toNum(x) ?? 0),
      'atan2': (dynamic a, dynamic b) =>
          math.atan2(_toNum(a) ?? 0, _toNum(b) ?? 1),
      'cos': (dynamic x) => math.cos(_toNum(x) ?? 0),
      'exp': (dynamic x) => math.exp(_toNum(x) ?? 0),
      'max': (List<dynamic> args) {
        // Ensure all values are numbers and filter out nulls; then find the max value
        var numbers = args.map(_toNum).whereType<num>().toList();
        if (numbers.isEmpty) return double.negativeInfinity;
        return numbers.reduce(math.max);
      },
      'min': (List<dynamic> args) {
        // Ensure all values are numbers and filter out nulls; then find the min value
        var numbers = args.map(_toNum).whereType<num>().toList();
        if (numbers.isEmpty) return double.infinity;
        return numbers.reduce(math.min);
      },
      'sin': (dynamic x) => math.sin(_toNum(x) ?? 0),
      'sqrt': (List<dynamic> args) {
        num val = 0;
        if (args.length > 0) {
          val = _toNum(args[0]);
        }
        return val.isNegative ? double.nan : math.sqrt(val);
      },
      'tan': (dynamic x) => math.tan(_toNum(x) ?? 0),
      'random': () => math.Random().nextDouble(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  @override
  callMethod(String methodName, List<dynamic> args) {
    Map<String, Function> _methods = methods();
    if (methodName == 'max' || methodName == 'min' || methodName == 'sqrt') {
      // Special handling for max and min to support multiple arguments.
      return _methods[methodName]!(args);
    } else if (_methods.containsKey(methodName)) {
      if (args.length > 0) {
        return Function.apply(_methods[methodName]!, args);
      } else {
        if (methodName == 'random') {
          return Function.apply(_methods[methodName]!, null);
        }
        return Function.apply(_methods[methodName]!, [null]);
      }
    } else {
      throw 'Method not found';
    }
  }
}