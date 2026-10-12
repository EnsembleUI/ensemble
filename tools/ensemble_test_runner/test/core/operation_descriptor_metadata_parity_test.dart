import 'package:ensemble_test_runner/src/runtime/operation_registry.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('registered names and aliases exactly match the generated vocabulary',
      () {
    final canonicalNames = <String>{};
    final aliasesByCanonical = <String, List<String>>{};

    for (final entry in TestStepRegistry.entries.entries) {
      if (entry.value.category == TestStepCategory.control) continue;
      final canonical = TestStepVocabulary.resolveStepType(entry.key);
      canonicalNames.add(canonical);
      if (entry.key != canonical) {
        aliasesByCanonical.putIfAbsent(canonical, () => []).add(entry.key);
      }

      final descriptor = operationRegistry.lookup(entry.key);
      expect(descriptor, isNotNull, reason: entry.key);
      expect(descriptor!.name, canonical, reason: entry.key);
      expect(operationRegistry.lookup(canonical), same(descriptor),
          reason: '${entry.key} must resolve to its canonical descriptor');
    }

    expect(
      operationRegistry.descriptors.map((descriptor) => descriptor.name),
      unorderedEquals(canonicalNames),
    );
    for (final descriptor in operationRegistry.descriptors) {
      expect(
        descriptor.aliases,
        unorderedEquals(aliasesByCanonical[descriptor.name] ?? const []),
        reason: '${descriptor.name} aliases',
      );
    }
  });

  test('aliases cannot declare a handler key that differs from canonical', () {
    for (final entry in TestStepRegistry.entries.entries) {
      final canonical = TestStepVocabulary.resolveStepType(entry.key);
      if (canonical == entry.key) continue;

      final declaredAliasHandler = entry.value.handlerKey;
      final canonicalMetadata = TestStepRegistry.entries[canonical]!;
      final canonicalHandler = canonicalMetadata.handlerKey ?? canonical;

      expect(
        declaredAliasHandler == null ||
            declaredAliasHandler == canonicalHandler,
        isTrue,
        reason: '${entry.key} resolves to $canonical and cannot override its '
            'runtime handler key',
      );
      expect(
        operationRegistry.lookup(entry.key)!.handlerKey,
        canonicalHandler,
        reason: '${entry.key} runtime dispatch must use the canonical handler',
      );
    }
  });

  test('default execution timing remains compatible', () {
    const config = TestExecutionConfig();

    expect(config.settleStepDuration, const Duration(milliseconds: 100));
    expect(config.settleTimeout, const Duration(seconds: 2));
    expect(config.actionSettleTimeout, const Duration(milliseconds: 150));
    expect(config.waitPollInterval, const Duration(milliseconds: 100));
    expect(config.defaultWaitTimeout, const Duration(seconds: 5));
  });

  test('operation descriptors preserve generated execution metadata', () {
    final waitKindsByCanonical = <String, Set<String>>{};
    final operationNamesByKind = {
      for (final kind in OperationKind.values) kind: <String>{},
    };
    for (final entry in TestStepRegistry.entries.entries) {
      final metadata = entry.value;
      if (metadata.category == TestStepCategory.control) {
        continue;
      }
      final canonical = TestStepVocabulary.resolveStepType(entry.key);
      operationNamesByKind[OperationKind.values.byName(
        metadata.executionKind.name,
      )]!
          .add(canonical);
      if (metadata.waitKind == null) continue;
      waitKindsByCanonical
          .putIfAbsent(canonical, () => <String>{})
          .add(metadata.waitKind!);
    }

    for (final entry in TestStepRegistry.entries.entries) {
      final metadata = entry.value;
      if (metadata.category == TestStepCategory.control) continue;

      final canonical = TestStepVocabulary.resolveStepType(entry.key);
      final descriptor = operationRegistry.lookup(entry.key);
      expect(descriptor, isNotNull, reason: entry.key);
      expect(
        descriptor!.name,
        TestStepVocabulary.resolveStepType(entry.key),
        reason: '${entry.key} canonical name',
      );
      expect(
        descriptor.handlerKey,
        TestStepRegistry.entries[canonical]!.handlerKey ?? canonical,
        reason: '${entry.key} runtime handler key',
      );
      expect(descriptor.kind.name, metadata.executionKind.name,
          reason: '${entry.key} execution kind');
      expect(descriptor.argumentSchema, metadata.argumentSchema,
          reason: '${entry.key} argument schema');
      expect(
        (descriptor.argumentSchema['properties'] as Map?)?.containsKey(
              'timeoutMs',
            ) ??
            false,
        (metadata.argumentSchema['properties'] as Map?)?.containsKey(
              'timeoutMs',
            ) ??
            false,
        reason: '${entry.key} timeout schema',
      );
      expect(descriptor.restrictedUiAllowed, metadata.restrictedUiAllowed,
          reason: '${entry.key} restricted-session permission');
      expect(descriptor.acceptsTimeout, metadata.acceptsTimeout,
          reason: '${entry.key} timeout acceptance');
      expect(
        descriptor.waitTargetState,
        metadata.waitTargetState,
        reason: '${entry.key} target wait state',
      );
      if (descriptor.acceptsTimeout) {
        final timeoutProperty =
            (descriptor.argumentSchema['properties'] as Map?)?['timeoutMs'];
        expect(
          timeoutProperty,
          {'type': 'integer'},
          reason: '${entry.key} accepted timeout schema',
        );
      }
      expect(
        descriptor.waitKind,
        TestStepRegistry.entries[canonical]!.waitKind,
        reason: '${entry.key} canonical wait kind',
      );
      expect(descriptor.userAction, metadata.userAction,
          reason: '${entry.key} action-evidence classification');
      expect(
        descriptor.orderedEvidenceAliases.contains(entry.key) ||
            (entry.key == canonical && descriptor.orderedEvidence),
        metadata.orderedEvidence,
        reason: '${entry.key} ordered evidence classification',
      );
      expect(
        descriptor.requiredCapabilities,
        metadata.requiredCapabilities,
        reason: '${entry.key} application capability requirements',
      );
      expect(
        descriptor.notifiesConditionMatched,
        metadata.notifiesConditionMatched,
        reason: '${entry.key} condition-match notification policy',
      );
      expect(
        descriptor.supportedWaitKinds,
        waitKindsByCanonical[canonical] ?? const <String>{},
        reason: '${entry.key} wait kinds including canonical aliases',
      );
    }

    for (final kind in OperationKind.values) {
      expect(
        operationRegistry.namesForKind(kind),
        operationNamesByKind[kind],
        reason: '${kind.name} operation capability projection',
      );
    }

    expect(
      operationRegistry.waitKinds,
      waitKindsByCanonical.values.expand((kinds) => kinds).toSet(),
    );
    expect(
      operationRegistry.lookup('waitFor')!.supportedWaitKinds,
      {'uiElement', 'text'},
    );
    expect(operationRegistry.lookup('waitForText'),
        same(operationRegistry.lookup('waitFor')));
  });

  test('control metadata maps explicitly to the plan control kinds', () {
    const kindMap = {
      TestStepControlKind.group: ControlKind.group,
      TestStepControlKind.repeat: ControlKind.repeat,
      TestStepControlKind.optional: ControlKind.optional,
      TestStepControlKind.ifVisible: ControlKind.ifVisible,
    };

    for (final entry in TestStepRegistry.entries.entries) {
      final metadata = entry.value;
      if (metadata.category == TestStepCategory.control) {
        final controlKind = metadata.controlKind;
        if (controlKind == null) {
          fail('${entry.key} must declare control-kind metadata');
        }
        expect(operationRegistry.isControl(entry.key), isTrue,
            reason: entry.key);
        expect(operationRegistry.controlKind(entry.key), kindMap[controlKind],
            reason: entry.key);
        expect(operationRegistry.lookup(entry.key), isNull,
            reason: '${entry.key} must not be routed as an operation');
      } else {
        expect(metadata.controlKind, isNull, reason: entry.key);
      }
    }
  });

  test('restricted interaction sets are the canonical metadata projection', () {
    final expectedAllowed = <String>{};
    final expectedExcluded = <String>{};
    for (final entry in TestStepRegistry.entries.entries) {
      final metadata = entry.value;
      if (metadata.category == TestStepCategory.control ||
          metadata.executionKind != TestStepExecutionKind.interaction) {
        continue;
      }

      final canonical = TestStepVocabulary.resolveStepType(entry.key);
      (metadata.restrictedUiAllowed ? expectedAllowed : expectedExcluded)
          .add(canonical);
    }

    expect(operationRegistry.restrictedUiNames, expectedAllowed);
    expect(operationRegistry.restrictedUiExcludedNames, expectedExcluded);
    expect(
      expectedAllowed.intersection(expectedExcluded),
      isEmpty,
    );
    expect(
      expectedAllowed.union(expectedExcluded),
      operationRegistry.namesForKind(OperationKind.interaction),
    );
  });

  test('wait permission categories come from operation metadata', () {
    expect(SessionCapabilities.local.waits, operationRegistry.waitKinds);
    expect(SessionPermissions.testController.waits,
        {'pump', 'settle', 'uiElement', 'text', 'navigation', 'api'});
  });

  test('session action grants come directly from operation metadata', () {
    final interactions = operationRegistry.namesForKind(
      OperationKind.interaction,
    );

    expect(SessionCapabilities.local.actions, interactions);
    expect(SessionPermissions.testController.actions, interactions);
    expect(
      SessionPermissions.restrictedUi.actions,
      operationRegistry.restrictedUiNames,
    );
  });

  test('application capability requirements are canonical registry metadata',
      () {
    const expected = <String, Set<String>>{
      'openScreen': {'ensembleHarness'},
      'reloadScreen': {'ensembleHarness'},
      'restartApp': {'ensembleHarness'},
      'launchApp': {'ensembleHarness'},
      'waitForApi': {'api'},
      'mocks': {'apiMocking'},
      'waitForNavigation': {'navigation'},
      'expectScreen': {'navigation'},
      'expectNavigateTo': {'navigation'},
      'expectVisited': {'navigation'},
      'expectNotVisited': {'navigation'},
      'expectBackStack': {'navigation'},
      'expectCanGoBack': {'navigation'},
      'goBack': {'navigation'},
      'resetApiCalls': {'api'},
      'expectApiCalled': {'api'},
      'expectApiNotCalled': {'api'},
      'expectApiCallOrder': {'api'},
      'expectLastApiCall': {'api'},
      'setStorage': {'storage'},
      'expectStorage': {'storage'},
      'removeStorage': {'storage'},
      'clearStorage': {'storage'},
    };

    for (final entry in TestStepRegistry.entries.entries) {
      final requirements = entry.value.requiredCapabilities;
      if (entry.value.category == TestStepCategory.control) {
        expect(requirements, isEmpty, reason: '${entry.key} control metadata');
        expect(operationRegistry.lookup(entry.key), isNull, reason: entry.key);
        continue;
      }
      expect(
        requirements,
        expected[entry.key] ?? const <String>{},
        reason: '${entry.key} capability metadata',
      );
      expect(
        operationRegistry.lookup(entry.key)?.requiredCapabilities,
        requirements,
        reason: '${entry.key} descriptor capability projection',
      );
    }
  });

  test('ordered capture policy includes every generated user action', () {
    final generatedActions = TestStepRegistry.entries.entries
        .where((entry) =>
            entry.value.category != TestStepCategory.control &&
            entry.value.userAction &&
            TestStepVocabulary.resolveStepType(entry.key) == entry.key)
        .map((entry) => entry.key)
        .toSet();
    final generatedOrderedEvidence = TestStepRegistry.entries.entries
        .where((entry) => entry.value.orderedEvidence)
        .map((entry) => entry.key)
        .toSet();

    expect(
      StepEvidencePolicy.orderedSteps,
      generatedOrderedEvidence,
      reason: 'Evidence capture classification must come from generated '
          'registry metadata.',
    );
    expect(
      StepEvidencePolicy.orderedSteps,
      containsAll(generatedActions),
      reason: 'Every operation classified as a user action needs an ordered '
          'evidence boundary.',
    );
    for (final stepName in StepEvidencePolicy.orderedSteps) {
      final descriptor = operationRegistry.lookup(stepName);
      expect(descriptor, isNotNull, reason: stepName);
      final metadata = TestStepRegistry.entries[stepName]!;
      expect(descriptor!.kind.name, metadata.executionKind.name,
          reason: '$stepName execution category');
      if (metadata.waitKind != null) {
        expect(
          descriptor.supportedWaitKinds,
          contains(metadata.waitKind),
          reason: '$stepName wait-specific match boundary',
        );
      }
    }

    for (final stepName in generatedActions) {
      expect(
        operationRegistry.lookup(stepName),
        isNotNull,
        reason: '$stepName must not outlive its operation descriptor',
      );
    }
  });
}
