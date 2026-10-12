import 'package:ensemble_test_runner/runner/attempt_execution_boundary.dart';
import 'package:ensemble_test_runner/runner/attempt_execution_context.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the mode-neutral phases of one test attempt in a fixed order.
///
/// Adapters provide preparation, launch, and execution callbacks. The shared
/// boundary continues to own scoped runtime hooks, cleanup, and failure
/// precedence; adapters retain their evidence and report policies.
final class AttemptLifecycleCoordinator {
  AttemptLifecycleCoordinator._({
    required this.boundary,
    required this.attemptContext,
  });

  /// Builds the common attempt context and scoped boundary from scheduler
  /// identity. Adapters then register only their mode-specific cleanup.
  factory AttemptLifecycleCoordinator.forAttempt({
    required String attemptId,
    required AttemptDescriptor attempt,
    required EnsembleTestCase test,
    required EnsembleTestConfig config,
    required WidgetTester tester,
    Object? checkpoint,
  }) {
    final attemptContext = AttemptExecutionContext.fromDescriptor(
      attemptId: attemptId,
      attempt: attempt,
      test: test,
      config: config,
      checkpoint: checkpoint,
    );
    final navigationFlow = attemptContext.runtime.navigationFlow;
    final boundary = AttemptExecutionBoundary(
      context: attemptContext.runtime,
      tester: tester,
    );
    // Register before startup: listener startup belongs to the guarded attempt
    // body so partial setup failures still reach the same teardown path.
    boundary.addCleanup(navigationFlow.stopListening);
    return AttemptLifecycleCoordinator._(
      attemptContext: attemptContext,
      boundary: boundary,
    );
  }

  final AttemptExecutionBoundary boundary;
  final AttemptExecutionContext attemptContext;

  /// Completes the shared transition from application launch to test journey.
  ///
  /// Direct driver launches and coordinated attempts must both flush queued
  /// launch routes before taking the current screen as the journey's start.
  static Future<T> launchAndBeginTest<T>({
    required NavigationFlowRecorder navigationFlow,
    required Future<T> Function() launch,
  }) async {
    late final T launched;
    try {
      launched = await launch();
    } catch (error, stackTrace) {
      // A failed launch can still have announced a route before bootstrap
      // failed. Preserve those transitions for failure reporting, while
      // keeping a reporting callback failure secondary to the launch failure.
      try {
        await navigationFlow.flushPending();
      } catch (_) {}
      Error.throwWithStackTrace(error, stackTrace);
    }
    await navigationFlow.beginTestAfterPending(
      ScreenTracker().getCurrentScreenIdentifier,
    );
    return launched;
  }

  /// Registers cleanup for a resource whose setup may fail partway through.
  ///
  /// The returned callback marks the point after which the resource is owned
  /// by this attempt. Standalone and hosted entry paths use the same rule for
  /// setup that can allocate before it throws.
  void Function() registerCleanupAfterStart(
    Future<void> Function() cleanup,
  ) {
    var started = false;
    boundary.addCleanup(() async {
      if (started) await cleanup();
    });
    return () => started = true;
  }

  Future<AttemptExecutionOutcome<T>> runCaptured<P, L, T>({
    required Future<P> Function() prepare,
    required Future<L> Function(P prepared) launch,
    required Future<T> Function(P prepared, L launched) execute,
    Future<void> Function(Object? bodyError, StackTrace? bodyStackTrace)?
        beforeClose,
  }) {
    return boundary.runCaptured<T>(
      body: () => _runPhases(
        prepare: prepare,
        launch: launch,
        execute: execute,
      ),
      beforeClose: beforeClose,
    );
  }

  Future<T> _runPhases<P, L, T>({
    required Future<P> Function() prepare,
    required Future<L> Function(P prepared) launch,
    required Future<T> Function(P prepared, L launched) execute,
  }) async {
    final runtime = attemptContext.runtime;
    await runtime.navigationFlow.startListeningWhenReady();
    final prepared = await prepare();
    final launched = await launchAndBeginTest(
      navigationFlow: runtime.navigationFlow,
      launch: () => launch(prepared),
    );
    return execute(prepared, launched);
  }
}
