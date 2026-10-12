import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/step_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the runtime uses one generic operation registry for aliases', () {
    final descriptors = operationRegistry.descriptors;
    final canonicalNames = descriptors.map((descriptor) => descriptor.name);

    expect(canonicalNames.toSet().length, descriptors.length);
    for (final descriptor in descriptors) {
      expect(operationRegistry.lookup(descriptor.name), same(descriptor));
      for (final alias in descriptor.aliases) {
        expect(operationRegistry.lookup(alias), same(descriptor),
            reason: '$alias should resolve through the canonical registry');
      }
    }
  });

  test('canonical runtime names match generated alias metadata', () {
    for (final entry in TestStepRegistry.entries.entries) {
      expect(
        operationRegistry.canonicalName(entry.key),
        TestStepVocabulary.resolveStepType(entry.key),
        reason: 'canonical runtime name differs for ${entry.key}',
      );
    }
    expect(operationRegistry.canonicalName('unregisteredStep'),
        'unregisteredStep');
  });

  test('user action policy matches generated and descriptor metadata', () {
    for (final entry in TestStepRegistry.entries.entries) {
      final descriptor = operationRegistry.lookup(entry.key);
      expect(descriptor?.userAction ?? false, entry.value.userAction,
          reason: 'descriptor mismatch for ${entry.key}');
      expect(
        isUserActionStep(TestStep(type: entry.key, args: const {})),
        entry.value.userAction,
        reason: 'capture policy mismatch for ${entry.key}',
      );
    }
  });

  test('timeout capability matches generated and descriptor metadata', () {
    for (final entry in TestStepRegistry.entries.entries) {
      expect(
        operationRegistry.lookup(entry.key)?.acceptsTimeout ?? false,
        entry.value.acceptsTimeout,
        reason: 'timeout metadata mismatch for ${entry.key}',
      );
    }
    expect(operationRegistry.lookup('expectText')?.acceptsTimeout, isTrue);
    expect(operationRegistry.lookup('expectNoText')?.acceptsTimeout, isFalse);
  });

  test('specialized dispatch keys are sourced from step metadata', () {
    for (final entry in TestStepRegistry.entries.entries) {
      final metadataKey = entry.value.handlerKey;
      if (metadataKey == null) continue;
      expect(operationRegistry.lookup(entry.key)?.handlerKey, metadataKey,
          reason: entry.key);
    }
  });

  test('environment operations all have direct handler identities', () {
    for (final entry in TestStepRegistry.entries.entries) {
      if (entry.value.executionKind.name != 'environment') continue;
      expect(entry.value.handlerKey, isNotNull, reason: entry.key);
      expect(operationRegistry.lookup(entry.key)?.handlerKey,
          entry.value.handlerKey,
          reason: entry.key);
    }
  });

  test('API assertions all have direct handler identities', () {
    const expected = {
      'expectApiCalled': 'assertion.apiCalled',
      'expectApiNotCalled': 'assertion.apiNotCalled',
      'expectApiCallOrder': 'assertion.apiCallOrder',
      'expectLastApiCall': 'assertion.lastApiCall',
    };
    for (final entry in expected.entries) {
      expect(operationRegistry.lookup(entry.key)?.handlerKey, entry.value,
          reason: entry.key);
    }
  });
}
