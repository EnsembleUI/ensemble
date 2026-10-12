import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_bootstrap.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('executor handlers cover every registered interaction',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    final context = EnsembleTestContext(
      testCase: const EnsembleTestCase(id: 'registry-coverage', steps: []),
      apiOverlay: TestApiProviderOverlay(mocks: const {}),
      logger: TestLogger(),
      setup: const EnsembleTestSetup(),
    );
    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
    );
    final interactions = TestStepRegistry.entries.entries.where(
      (entry) => entry.value.executionKind == TestStepExecutionKind.interaction,
    );

    for (final entry in interactions) {
      final canonicalName = TestStepVocabulary.resolveStepType(entry.key);
      final descriptor = operationRegistry.lookup(canonicalName);
      expect(descriptor, isNotNull, reason: entry.key);
      expect(descriptor!.kind, OperationKind.interaction, reason: entry.key);
      expect(
        executor.registeredOperationHandlerKeys,
        contains(descriptor.handlerKey),
        reason: '${entry.key} must have a registered executor handler.',
      );
    }

    expect(
      executor.registeredOperationHandlerKeys,
      equals(operationRegistry.handlerKeys),
      reason:
          'The executor handler map must cover every registry operation and no unregistered handlers.',
    );
  });
}
