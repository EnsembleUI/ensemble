import 'dart:math';

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class InvokableMath extends Object with Invokable {
  InvokableMath();
  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'floor': (num n) => n.floor(),
      'abs': (num n) => n.abs(),
      'ceil': (num n) => n.ceil(),
      'round': (num n) => n.round(),
      'trunc': (num n) => n.truncate(),
      'log': (num n) => log(n),
      'pow': (num x, num y) => pow(x, y),
      'acos': (num n) => acos(n),
      'asin': (num n) => asin(n),
      'atan': (num x) => atan(x),
      'atan2': (num a,num b) => atan2(a, b),
      'cos': (num x) => cos(x),
      'exp': (num x) => exp(x),
      'max': (num a,num b) => max(a, b),
      'min': (num a, num b) => min(a, b),
      'sin': (num x) => sin(x),
      'sqrt': (num x) => sqrt(x),
      'tan': (num x) => tan(x),
      'random': () => Random().nextDouble(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}