import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
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

  test('every registry entry has a JSON Schema', () {
    for (final entry in TestStepRegistry.entries.values) {
      expect(entry.argKind.jsonSchema, isA<Map<String, dynamic>>());
      expect(entry.argKind.jsonSchema['type'], 'object');
    }
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
