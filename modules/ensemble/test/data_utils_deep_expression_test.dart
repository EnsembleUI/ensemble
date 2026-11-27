import 'package:ensemble/framework/data_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Chart-like data: a list of series, each with a list of values.
  final chartData = [
    {
      'values': [r'${done.text}', r'${remaining.text}'],
      'colors': ['#FF0000', r'${doneColor}'],
    }
  ];

  group('parseDeepDataExpression', () {
    test('finds expressions at any depth', () {
      final expression = DataUtils.parseDeepDataExpression(chartData)!;
      expect(expression.expressions,
          [r'${done.text}', r'${remaining.text}', r'${doneColor}']);
      // The whole value is re-evaluated when any of them changes.
      expect(expression.rawExpression, same(chartData));
    });

    test('gives null when there is no expression', () {
      expect(
          DataUtils.parseDeepDataExpression([
            {
              'values': [1, 2]
            }
          ]),
          isNull);
    });

    test('treats a single string like parseDataExpression', () {
      expect(DataUtils.parseDeepDataExpression(r'${data}')!.expressions,
          DataUtils.parseDataExpression(r'${data}')!.expressions);
    });
  });

  test('parseDataExpression still only looks one level down', () {
    // Unchanged for every widget that doesn't opt in with HasDeepBindings.
    expect(DataUtils.parseDataExpression(chartData), isNull);
  });
}
