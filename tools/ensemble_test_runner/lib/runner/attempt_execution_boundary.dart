import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ensemble_test_runner/runner/attempt_runtime_scope.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/src/core/async_cleanup_stack.dart';
import 'package:ensemble_test_runner/src/core/primary_failure.dart';

/// Owns the common execution boundary for one test attempt.
///
/// The application adapters still decide what to launch and how to report a
/// failure. This boundary owns the part that must be identical in both
/// adapters: install attempt-local runtime hooks, execute inside the captured
/// console zone, run adapter cleanup while those hooks are still active, and
/// restore the previous isolate state. A body failure always remains primary
/// when cleanup also fails. Each instance represents exactly one attempt and
/// is single-use; attempts must get distinct boundaries to isolate hooks.
final class AttemptExecutionBoundary {
  AttemptExecutionBoundary({
    required EnsembleTestContext context,
    required WidgetTester tester,
    void Function() Function()? captureDebugPrint,
  })  : _scope = AttemptRuntimeScope(
          context: context,
          tester: tester,
          captureDebugPrint: captureDebugPrint,
        ),
        _zone = context.runtime.consoleCaptureZone;

  final AttemptRuntimeScope _scope;
  final ZoneSpecification _zone;
  final AsyncCleanupStack _cleanup = AsyncCleanupStack();
  var _runStarted = false;

  /// Register resources owned by this attempt.
  ///
  /// These callbacks run after adapter-specific close work and before the
  /// attempt runtime scope is restored. Both execution paths use this same
  /// owner so setup failures and normal completion drain resources uniformly.
  void addCleanup(Future<void> Function() callback) => _cleanup.add(callback);

  Future<T> run<T>({
    required Future<T> Function() body,
    Future<void> Function(Object? bodyError, StackTrace? bodyStackTrace)?
        beforeClose,
  }) async {
    final outcome = await runCaptured<T>(
      body: body,
      beforeClose: beforeClose,
    );
    return outcome.requireValue();
  }

  /// Runs an attempt while preserving its body and close failures as data.
  ///
  /// Application adapters use this form when they need to turn a failed
  /// attempt into a report. The same scope, zone, and close ordering as
  /// [run] is retained, so adapters do not need a second attempt boundary.
  Future<AttemptExecutionOutcome<T>> runCaptured<T>({
    required Future<T> Function() body,
    Future<void> Function(Object? bodyError, StackTrace? bodyStackTrace)?
        beforeClose,
  }) async {
    if (_runStarted) {
      throw StateError('An attempt execution boundary can run only once.');
    }
    // Claim the boundary before opening process-wide hooks. A concurrent
    // second call must not enter its `finally` path and close the first run's
    // scope while its body is still using those hooks.
    _runStarted = true;
    Object? bodyError;
    StackTrace? bodyStackTrace;
    T? value;
    var completed = false;
    Object? closeError;
    StackTrace? closeStackTrace;
    final closeFailures = <({Object error, StackTrace stackTrace})>[];
    try {
      try {
        _scope.open();
        value = await runZoned(body, zoneSpecification: _zone);
        completed = true;
      } catch (error, stackTrace) {
        bodyError = error;
        bodyStackTrace = stackTrace;
      }
      try {
        await beforeClose?.call(bodyError, bodyStackTrace);
      } catch (error, stackTrace) {
        closeError = error;
        closeStackTrace = stackTrace;
        closeFailures.add((error: error, stackTrace: stackTrace));
      }
      try {
        await _cleanup.close();
      } catch (error, stackTrace) {
        closeError ??= error;
        closeStackTrace ??= stackTrace;
        closeFailures.addAll(_cleanup.failures);
      }
    } finally {
      try {
        _scope.close();
      } catch (error, stackTrace) {
        closeError ??= error;
        closeStackTrace ??= stackTrace;
      }
      final scopeFailures = _scope.closeFailures;
      if (scopeFailures.isNotEmpty) {
        closeFailures.addAll(scopeFailures);
      } else if (closeError != null && closeFailures.isEmpty) {
        closeFailures.add((error: closeError, stackTrace: closeStackTrace!));
      }
    }
    return AttemptExecutionOutcome<T>(
      value: value,
      completed: completed,
      bodyError: bodyError,
      bodyStackTrace: bodyStackTrace,
      closeError: closeError,
      closeStackTrace: closeStackTrace,
      closeFailures: List.unmodifiable(closeFailures),
    );
  }
}

/// Captured outcome for adapters that project an attempt into a test report.
final class AttemptExecutionOutcome<T> {
  const AttemptExecutionOutcome({
    required this.value,
    required this.completed,
    required this.bodyError,
    required this.bodyStackTrace,
    required this.closeError,
    required this.closeStackTrace,
    required this.closeFailures,
  });

  final T? value;
  final bool completed;
  final Object? bodyError;
  final StackTrace? bodyStackTrace;
  final Object? closeError;
  final StackTrace? closeStackTrace;

  /// All adapter, registered-resource, and scope restoration failures.
  /// [closeError] remains the first such failure for existing projections.
  final List<({Object error, StackTrace stackTrace})> closeFailures;

  /// Body failures take precedence over cleanup and scope-restoration
  /// failures. Both application adapters use this same attempt-level rule.
  ({Object error, StackTrace stackTrace})? get primaryFailure {
    return selectPrimaryFailure(
      operationError: bodyError,
      operationStackTrace: bodyStackTrace,
      cleanupError: closeError,
      cleanupStackTrace: closeStackTrace,
    );
  }

  /// Returns the body value or throws the selected attempt failure.
  ///
  /// Result-returning adapters can inspect [primaryFailure] and project it
  /// into their own report, while value-returning callers use this single
  /// shared conversion so cleanup precedence cannot drift between entry paths.
  T requireValue() {
    final failure = primaryFailure;
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    if (!completed) {
      throw StateError('Attempt body completed without a result.');
    }
    return value as T;
  }
}
