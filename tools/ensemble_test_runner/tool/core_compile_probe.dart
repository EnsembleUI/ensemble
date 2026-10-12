// This entry point intentionally imports every pure-Dart core library.
// `check_core_compile.dart` compiles it with the Dart SDK so the boundary is
// checked independently of Flutter's analyzer and test runner.
import 'package:ensemble_test_runner/src/core/async_cleanup_stack.dart';
import 'package:ensemble_test_runner/src/core/attempt_artifact_subscriber.dart';
import 'package:ensemble_test_runner/src/core/attempt_coordinator.dart';
import 'package:ensemble_test_runner/src/core/cleanup_after_failure.dart';
import 'package:ensemble_test_runner/src/core/compiler.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';
import 'package:ensemble_test_runner/src/core/operation_registry.dart';
import 'package:ensemble_test_runner/src/core/plan.dart';
import 'package:ensemble_test_runner/src/core/plan_wire_transport.dart';
import 'package:ensemble_test_runner/src/core/primary_failure.dart';
import 'package:ensemble_test_runner/src/core/policy.dart';
import 'package:ensemble_test_runner/src/core/retry_scheduler.dart';
import 'package:ensemble_test_runner/src/core/runtime.dart';
import 'package:ensemble_test_runner/src/core/step_capture_guard.dart';
import 'package:ensemble_test_runner/src/core/step_boundary_subscriber.dart';
import 'package:ensemble_test_runner/src/core/step_execution_tracker.dart';
import 'package:ensemble_test_runner/src/core/step_performance_subscriber.dart';
import 'package:ensemble_test_runner/src/core/step_context_subscriber.dart';
import 'package:ensemble_test_runner/src/core/step_timing_subscriber.dart';
import 'package:ensemble_test_runner/src/core/suite_checkpoint_scheduler.dart';

void main() {
  // Keep a reference to each library's public surface. This prevents a
  // future library from becoming accidentally unreachable from the probe.
  final references = <Object?>[
    AsyncCleanupStack,
    AttemptArtifactSubscriber,
    AttemptCoordinator,
    runWithCleanupPreservingPrimary,
    PlanCompiler,
    ExecutionKernelRunner,
    ExecutionKernel,
    TestOperation,
    OperationInput,
    OperationRegistry,
    ExecutionPlan,
    ExecutionPlanWireTransport,
    selectPrimaryFailure,
    ExecutionPolicy,
    RetryScheduler,
    TestRuntime,
    StepCaptureGuard,
    StepBoundarySubscriber,
    StepExecutionTracker,
    StepPerformanceSubscriber,
    StepContextSubscriber,
    StepTimingSubscriber,
    SuiteCheckpointScheduler,
  ];
  if (references.length != 23) {
    throw StateError('Core compile probe is incomplete.');
  }
}
