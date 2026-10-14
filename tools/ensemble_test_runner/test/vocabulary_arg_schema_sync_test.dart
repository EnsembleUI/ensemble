import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registry and vocabulary definitions stay in sync', () {
    expect(
      TestStepRegistry.entries.length,
      TestStepVocabulary.definitions.length,
    );
    for (final name in TestStepRegistry.entries.keys) {
      expect(TestStepVocabulary.definitions, contains(name));
      expect(
        TestStepVocabulary.definitions[name]!.argKind,
        TestStepRegistry.entries[name]!.argKind,
      );
    }
  });

  test('vocabulary definitions expose immutable metadata', () {
    final definition = TestStepVocabulary.definitions['httpRequest']!;

    expect(
      () => TestStepVocabulary.definitions['newStep'] = definition,
      throwsUnsupportedError,
    );
    expect(
      () => definition.example['url'] = 'https://changed.invalid',
      throwsUnsupportedError,
    );
    expect(
      () => (definition.argumentSchema['properties'] as Map)['url'] = {
        'type': 'integer',
      },
      throwsUnsupportedError,
    );
  });

  test('every registry entry has a JSON Schema', () {
    for (final entry in TestStepRegistry.entries.values) {
      expect(entry.argKind.jsonSchema, isA<Map<String, dynamic>>());
      expect(entry.argKind.jsonSchema['type'], 'object');
    }
  });

  test('timeout metadata stays aligned across registry and generated schema',
      () {
    final expectTextEntry = TestStepRegistry.entries['expectText']!;
    final expectNoTextEntry = TestStepRegistry.entries['expectNoText']!;
    final expectText = operationRegistry.lookup('expectText')!;
    final expectNoText = operationRegistry.lookup('expectNoText')!;

    expect(expectTextEntry.acceptsTimeout, isTrue);
    expect(expectNoTextEntry.acceptsTimeout, isFalse);
    expect(
      (expectText.argumentSchema['properties'] as Map).keys,
      contains('timeoutMs'),
    );
    expect(
      (expectNoText.argumentSchema['properties'] as Map).keys,
      isNot(contains('timeoutMs')),
    );
    expect(
      TestStepVocabulary.argJsonSchemaForKey('expectText'),
      expectText.argumentSchema,
    );
    expect(
      TestStepVocabulary.argJsonSchemaForKey('expectNoText'),
      expectNoText.argumentSchema,
    );
  });

  test('every registry entry has a non-empty description', () {
    for (final e in TestStepRegistry.entries.entries) {
      expect(
        e.value.description.trim(),
        isNotEmpty,
        reason: 'missing description for ${e.key}',
      );
    }
  });

  test('every registry entry has an example args map', () {
    for (final e in TestStepRegistry.entries.entries) {
      expect(
        e.value.example,
        isA<Map<String, dynamic>>(),
        reason: 'missing example for ${e.key}',
      );
      expect(
        TestStepVocabulary.definitions[e.key]!.example,
        e.value.example,
      );
    }
  });
}
