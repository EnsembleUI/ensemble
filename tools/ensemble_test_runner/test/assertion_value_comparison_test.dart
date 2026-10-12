import 'package:ensemble_test_runner/assertions/assertion_value_comparison.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compares maps with different key types after normalization', () {
    expect(
      AssertionValueComparison.deepEquals(
        <Object, Object>{
          1: <String, Object>{'ready': true}
        },
        <String, Object>{
          '1': <String, Object>{'ready': true}
        },
      ),
      isTrue,
    );
  });

  test('compares JSON text with decoded values', () {
    expect(
      AssertionValueComparison.deepEquals(
        '[{"name":"demo","enabled":true}]',
        <Map<String, Object>>[
          <String, Object>{'name': 'demo', 'enabled': true},
        ],
      ),
      isTrue,
    );
  });

  test('preserves list ordering and rejects different values', () {
    expect(
      AssertionValueComparison.deepEquals(<Object>[1, 2], <Object>[2, 1]),
      isFalse,
    );
    expect(
      AssertionValueComparison.deepEquals(<Object>[1, 2], <Object>[1, 2]),
      isTrue,
    );
  });

  test('keeps malformed JSON-like text as text', () {
    expect(
      AssertionValueComparison.deepEquals('{not-json}', '{not-json}'),
      isTrue,
    );
    expect(
      AssertionValueComparison.deepEquals('{not-json}', <String, Object>{}),
      isFalse,
    );
  });
}
