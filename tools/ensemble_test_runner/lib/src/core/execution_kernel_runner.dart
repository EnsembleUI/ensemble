import 'dart:async';

import 'kernel.dart';
import 'plan.dart';
import 'policy.dart';
import 'runtime.dart';

/// Creates and runs the shared execution kernel for one attempt.
///
/// Entry points may differ in how they prepare a runtime, but they must not
/// grow separate kernel construction rules. Keeping this small boundary in
/// the core also gives future execution controllers one stable seam for
/// supplying policy, limits, cancellation, and event subscribers.
final class ExecutionKernelRunner {
  const ExecutionKernelRunner({
    required this.plan,
    required this.runtime,
    this.policy,
    this.limits = const ExecutionLimits(),
    this.cancellation,
    this.eventSubscribers = const [],
    this.eventSubscriptions = const [],
  });

  final ExecutionPlan plan;
  final TestRuntime runtime;
  final ExecutionPolicy? policy;
  final ExecutionLimits limits;
  final ExecutionCancellation? cancellation;
  final Iterable<EventSink> eventSubscribers;
  final Iterable<EventSubscription> eventSubscriptions;

  Future<AttemptResult> run() => ExecutionKernel(
        plan: plan,
        policy: policy ?? CompiledExecutionPolicy(plan),
        runtime: runtime,
        limits: limits,
        cancellation: cancellation,
        eventSubscribers: eventSubscribers,
        eventSubscriptions: eventSubscriptions,
      ).run();
}
