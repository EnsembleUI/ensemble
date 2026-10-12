import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';

/// The immutable inputs shared by every execution attempt.
///
/// Standalone and application-owned suites still have different launch and
/// cleanup policies, but they must agree on attempt numbering and the
/// context passed to the driver. Keeping that translation here prevents the
/// two entry points from drifting while their execution bodies are merged.
final class AttemptExecutionContext {
  AttemptExecutionContext._({
    required this.launch,
    required this.runtime,
  });

  factory AttemptExecutionContext.fromDescriptor({
    required String attemptId,
    required AttemptDescriptor attempt,
    required EnsembleTestCase test,
    required EnsembleTestConfig config,
    Object? checkpoint,
  }) {
    if (attempt.number != attempt.index + 1 ||
        attempt.total < 1 ||
        attempt.index < 0 ||
        attempt.index >= attempt.total) {
      throw ArgumentError.value(
        attempt,
        'attempt',
        'must have a one-based number matching its in-range zero-based index',
      );
    }
    final runtime = EnsembleTestContext.fromTestCase(
      test,
      config: config,
      navigationFlow: NavigationFlowRecorder(),
    );
    runtime.runtime.attemptNumber = attempt.number;
    runtime.runtime.attemptCount = attempt.total;
    return AttemptExecutionContext._(
      launch: TestLaunchContext(
        attemptId: attemptId,
        attempt: attempt.index,
        testCase: test,
        config: config,
        checkpoint: checkpoint,
      ),
      runtime: runtime,
    );
  }

  final TestLaunchContext launch;
  final EnsembleTestContext runtime;
}
