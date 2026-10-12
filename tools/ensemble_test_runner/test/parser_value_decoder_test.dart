import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/parser_value_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes nested maps and lists while resolving typed inputs', () {
    final decoded = ParserValueDecoder.toStringDynamicMap(
      {
        'count': r'${inputs.count}',
        'nested': [
          {'enabled': true},
          r'${inputs.label}',
        ],
      },
      inputs: const {'count': 3, 'label': 'ready'},
    );

    expect(decoded, {
      'count': 3,
      'nested': [
        {'enabled': true},
        'ready',
      ],
    });
  });

  test('leaves scenario placeholders unresolved before scenario expansion', () {
    expect(
      ParserValueDecoder.resolvePlaceholders(
        r'fixtures/${scenario.device}.json',
        inputs: const {},
        scenario: const {},
      ),
      r'fixtures/${scenario.device}.json',
    );
  });

  test('reports missing values with the namespace-specific error', () {
    expect(
      () => ParserValueDecoder.resolvePlaceholders(
        r'${inputs.token}',
        inputs: const {},
        scenario: const {},
      ),
      throwsA(
        isA<EnsembleTestFailure>().having(
          (error) => error.message,
          'message',
          contains('Missing CLI input "token"'),
        ),
      ),
    );
  });
}
