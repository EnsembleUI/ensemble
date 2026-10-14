import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/actions/navigation_waiter.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/operation_result.dart';
import 'package:ensemble_test_runner/session/local/flutter_target_resolver.dart';
import 'package:ensemble_test_runner/session/local/local_session_policy.dart';
import 'package:ensemble_test_runner/session/local/leaf_command_queue.dart';
import 'package:ensemble_test_runner/src/core/operation.dart'
    show OperationKind, TestOperation;
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:flutter_test/flutter_test.dart';

/// Executes the session's wait conditions behind the session boundary.
///
/// Keeping condition translation here leaves [LocalTestExecutionSession]
/// responsible for lifecycle and resource ownership while preserving one
/// queue, policy, resolver, and executor for every wait.
class LocalSessionWaitOperations {
  LocalSessionWaitOperations({
    required this.tester,
    required this.context,
    required this.executor,
    required this.policy,
    required this.resolver,
    required this.queue,
    required this.ensureOpen,
    required this.nextOperationId,
    required this.mapExecutorFailure,
  });

  final WidgetTester tester;
  final EnsembleTestContext context;
  final TestStepExecutor executor;
  final LocalSessionPolicy policy;
  final FlutterTargetResolver resolver;
  final LeafCommandQueue queue;
  final void Function() ensureOpen;
  final String Function(String prefix) nextOperationId;
  final TestExecutionError Function(EnsembleTestFailure error)
      mapExecutorFailure;

  late final NavigationWaiter _navigationWaiter = NavigationWaiter(
    tester: tester,
    context: context,
    navigation: executor.services.navigation,
    config: executor.config,
  );

  /// Executes one registry-selected wait request.
  Future<WaitResult> waitFor(TestOperation operation, {Duration? timeout}) {
    return RunnerBenchmark.future('session', 'waitOperation', () {
      ensureOpen();
      final descriptor = operationRegistry.requireDescriptor(
        operation,
        expectedKind: OperationKind.wait,
      );
      final input = Map<String, dynamic>.from(operation.input);
      final requestsText = input['text'] != null || input['anyOf'] is List;
      final waitKind =
          descriptor.supportedWaitKinds.contains('text') && requestsText
              ? 'text'
              : descriptor.waitKind;
      if (waitKind == null) {
        throw StateError(
          'Wait operation "${descriptor.name}" has no wait kind metadata.',
        );
      }
      return queue.run(() async {
        resolver.invalidateResolvedFinders();
        final waitId = nextOperationId('wait');
        final sw = Stopwatch()..start();
        try {
          policy.ensureWaitKindPermitted(waitKind);
          final effectiveOperation = _withTimeoutOverride(operation, timeout);
          final effectiveInput = effectiveOperation.input;
          if (waitKind == 'navigation') {
            final screen = effectiveInput['screen']?.toString() ?? '';
            await _navigationWaiter.waitForNavigation(
              screen: screen,
              timeoutMs: NavigationWaiter.timeoutMsFor(
                effectiveOperation,
                defaultTimeout: executor.config.defaultWaitTimeout,
              ),
              onMatched: () => _emitNavigationMatch(operation),
            );
            return WaitResult(
              waitId: waitId,
              status: WaitStatus.satisfied,
              duration: sw.elapsed,
            );
          }
          await executor.executeWaitOperation(effectiveOperation);
          return WaitResult(
            waitId: waitId,
            status: WaitStatus.satisfied,
            duration: sw.elapsed,
          );
        } on TestExecutionError catch (error) {
          return WaitResult(
            waitId: waitId,
            status: error.code == TestExecutionErrorCode.actionTimeout
                ? WaitStatus.timedOut
                : WaitStatus.failed,
            duration: sw.elapsed,
            error: error,
          );
        } on EnsembleTestFailure catch (error) {
          final mapped = mapExecutorFailure(error);
          return WaitResult(
            waitId: waitId,
            status: mapped.code == TestExecutionErrorCode.actionTimeout
                ? WaitStatus.timedOut
                : WaitStatus.failed,
            duration: sw.elapsed,
            error: mapped,
          );
        }
      });
    });
  }

  /// Applies the session-level timeout consistently across all wait routes.
  /// An explicit method argument overrides the operation's serialized default.
  TestOperation _withTimeoutOverride(
    TestOperation operation,
    Duration? timeout,
  ) {
    if (timeout == null) return operation;
    return TestOperation(
      id: operation.id,
      name: operation.name,
      kind: operation.kind,
      handlerKey: operation.handlerKey,
      input: {
        ...operation.input,
        'timeoutMs': timeout.inMilliseconds,
      },
      source: operation.source,
    );
  }

  Future<void> _emitNavigationMatch(TestOperation operation) async {
    await executor.onOperationEvidenceBoundary?.call(
      operation,
      operation.name,
    );
  }
}
