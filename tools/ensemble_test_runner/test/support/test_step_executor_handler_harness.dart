import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind;
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart'
    show StepEvidencePolicy;

/// Test-only adapter for focused executor behavior tests.
///
/// It routes leaf inputs through the registry-selected handlers. Structural
/// control flow belongs to compiled-plan/kernel tests and is intentionally not
/// reproduced here.
extension TestStepExecutorHandlerHarness on TestStepExecutor {
  Future<void> execute(TestStep step) async {
    final descriptor = operationRegistry.lookup(step.type);
    if (descriptor == null) {
      final detail = operationRegistry.isControl(step.type)
          ? 'Structural control flow must be exercised through the execution '
              'kernel.'
          : 'Unknown test operation "${step.type}".';
      throw StateError(detail);
    }

    final input = descriptor.aliases.contains(step.type) &&
            descriptor.kind != OperationKind.wait
        ? _canonicalStep(step, descriptor.name)
        : step;

    if (descriptor.kind == OperationKind.wait) {
      await executeRegisteredWaitInput(input, descriptor: descriptor);
      return;
    }
    if (descriptor.kind == OperationKind.lifecycle) {
      await executeRegisteredLifecycleInput(descriptor, input);
      return;
    }

    final handled = await executeRegisteredInteraction(
      input,
      descriptor: descriptor,
    );
    if (!handled) {
      throw StateError(
        'No handler for test operation "${descriptor.name}".',
      );
    }
    if ((descriptor.kind == OperationKind.assertion ||
            descriptor.notifiesConditionMatched) &&
        StepEvidencePolicy.isConditionStep(input.type)) {
      await onEvidenceBoundary?.call(
        _canonicalStep(
          input,
          '${StepEvidencePolicy.conditionBoundaryPrefix}${input.type}',
        ),
      );
    }
  }
}

TestStep _canonicalStep(TestStep step, String type) => TestStep(
      type: type,
      args: step.args,
      mocks: step.mocks,
      nestedSteps: step.nestedSteps,
    );
