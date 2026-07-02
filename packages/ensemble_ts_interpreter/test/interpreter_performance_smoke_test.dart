import 'package:ensemble_ts_interpreter/invokables/context.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:test/test.dart';

dynamic evalJs(String code, [Map<String, dynamic>? context]) {
  final ctx = context ?? <String, dynamic>{};
  return JSInterpreter.fromCode(code, SimpleContext(ctx)).evaluate();
}

void main() {
  group('Interpreter performance smoke baselines', () {
    test('common hot paths execute repeatedly without thresholds', () {
      final scenarios = <String, String>{
        'parse and evaluate simple expression': 'var result = 1 + 2 + 3;',
        'nested property lookup': '''
          var data = { user: { profile: { count: 1 } } };
          var result = data.user.profile.count;
        ''',
        'function call': '''
          function add(a, b) { return a + b; }
          var result = add(1, 2);
        ''',
        'method call with this': '''
          var obj = { value: 1, inc: function() { this.value++; } };
          obj.inc();
        ''',
        'array callback iteration': '''
          var arr = [1, 2, 3, 4, 5];
          var result = arr.map(function(v) { return v * 2; });
        ''',
      };

      for (final entry in scenarios.entries) {
        final sw = Stopwatch()..start();
        for (var i = 0; i < 50; i++) {
          evalJs(entry.value, {});
        }
        sw.stop();
        // ignore: avoid_print
        print('${entry.key}: ${sw.elapsedMicroseconds}us for 50 runs');
      }
    });

    test('pre-parsed AST evaluation has a baseline', () {
      const code = '''
        var obj = { a: 1, b: 2 };
        var result = obj.a + obj.b;
      ''';
      final program = JSInterpreter.parseCode(code);

      final sw = Stopwatch()..start();
      for (var i = 0; i < 50; i++) {
        JSInterpreter(code, program, SimpleContext({})).evaluate();
      }
      sw.stop();

      // ignore: avoid_print
      print('pre-parsed AST evaluate: ${sw.elapsedMicroseconds}us for 50 runs');
    });
  });
}
