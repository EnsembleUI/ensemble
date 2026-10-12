import 'dart:async';

import 'plan.dart';
import 'policy.dart';
import 'runtime.dart';
import 'operation.dart';

enum AttemptOutcome { passed, failed, cancelled, limitExceeded }

enum ExecutionEventKind {
  attemptStarted,
  stepStarted,
  stepFinished,
  directiveSelected,
  observationCaptured,
  observationFailed,
  operationStarted,
  operationFinished,
  evidenceBoundary,
  attemptFinished,
}

final class ExecutionEvent {
  const ExecutionEvent({
    required this.sequence,
    required this.kind,
    this.nodeId,
    this.detail,
    this.operation,
    this.source,
    this.stepIndex,
  });

  final int sequence;
  final ExecutionEventKind kind;
  final String? nodeId;
  final String? detail;

  /// Canonical registry name for operation events.
  final String? operation;
  final SourceLocation? source;
  final int? stepIndex;
}

typedef EventSink = FutureOr<void> Function(ExecutionEvent event);

/// An event handler registered only for the event kinds it consumes.
///
/// Filtering happens while the kernel builds its dispatch table, so hot-path
/// events do not call unrelated subscribers merely to have them return early.
final class EventSubscription {
  EventSubscription({
    required Iterable<ExecutionEventKind> kinds,
    required this.handle,
  }) : kinds = Set.unmodifiable(kinds) {
    if (this.kinds.isEmpty) {
      throw ArgumentError.value(kinds, 'kinds', 'Must not be empty.');
    }
  }

  final Set<ExecutionEventKind> kinds;
  final EventSink handle;
}

final class ExecutionLimits {
  const ExecutionLimits({
    this.maxOperations = 1000,
    this.maxDirectives = 10000,
    this.maxLoopEntries = 10000,
    this.wallTime = const Duration(minutes: 10),
  })  : assert(maxOperations > 0),
        assert(maxDirectives > 0),
        assert(maxLoopEntries > 0);

  final int maxOperations;
  final int maxDirectives;

  /// Maximum number of loop-body entries in one attempt. This is separate
  /// from the directive budget so a malformed or unexpectedly large plan
  /// cannot consume the attempt through loop transitions alone.
  final int maxLoopEntries;
  final Duration wallTime;
}

final class ExecutionCancellation {
  bool _cancelled = false;

  /// Whether cancellation was requested by the owner of this attempt.
  bool get isCancelled => _cancelled;

  /// Requests cancellation. Repeated requests are harmless.
  void cancel() => _cancelled = true;
}

final class AttemptResult {
  AttemptResult({
    required this.outcome,
    required this.operations,
    required this.events,
    this.primaryFailure,
    this.failureCode,
    this.failureSource,
    this.failureOperation,
    this.cause,
    this.stackTrace,
    List<String> secondaryFailures = const [],
  }) : secondaryFailures = List.unmodifiable(secondaryFailures);

  final AttemptOutcome outcome;
  final int operations;
  final int events;
  final String? primaryFailure;
  final String? failureCode;
  final SourceLocation? failureSource;

  /// Canonical operation name responsible for the primary failure, when the
  /// failure occurred while executing an operation.
  final String? failureOperation;
  final Object? cause;
  final StackTrace? stackTrace;
  final List<String> secondaryFailures;
}

/// Owns one execution attempt. The runtime is closed exactly once by run().
final class ExecutionKernel {
  ExecutionKernel({
    required this.plan,
    required this.policy,
    required this.runtime,
    this.limits = const ExecutionLimits(),
    this.cancellation,
    Iterable<EventSink> eventSubscribers = const [],
    Iterable<EventSubscription> eventSubscriptions = const [],
  })  : eventSubscribers = List.unmodifiable(eventSubscribers),
        eventSubscriptions = List.unmodifiable(eventSubscriptions),
        _subscribersByKind = _indexSubscribers(
          eventSubscribers,
          eventSubscriptions,
        );

  final ExecutionPlan plan;
  final ExecutionPolicy policy;
  final TestRuntime runtime;
  final ExecutionLimits limits;
  final ExecutionCancellation? cancellation;

  final List<EventSink> eventSubscribers;
  final List<EventSubscription> eventSubscriptions;
  final Map<ExecutionEventKind, List<EventSink>> _subscribersByKind;

  static Map<ExecutionEventKind, List<EventSink>> _indexSubscribers(
    Iterable<EventSink> subscribers,
    Iterable<EventSubscription> subscriptions,
  ) {
    // Most standalone executions disable optional reporting subscribers. Do
    // not build an empty dispatch table for that common path; `publish` counts
    // events without consulting this map when both registration lists are
    // empty.
    if (subscribers.isEmpty && subscriptions.isEmpty) return const {};

    final indexed = <ExecutionEventKind, List<EventSink>>{
      for (final kind in ExecutionEventKind.values) kind: <EventSink>[],
    };
    for (final subscriber in subscribers) {
      for (final handlers in indexed.values) {
        handlers.add(subscriber);
      }
    }
    for (final subscription in subscriptions) {
      for (final kind in subscription.kinds) {
        indexed[kind]!.add(subscription.handle);
      }
    }
    return Map.unmodifiable({
      for (final entry in indexed.entries)
        entry.key: List<EventSink>.unmodifiable(entry.value),
    });
  }

  Future<AttemptResult> run() async {
    var nodeId = plan.start;
    final loopCounts = <String, int>{};
    RuntimeView? view;
    var operationCount = 0;
    var directiveCount = 0;
    var loopEntryCount = 0;
    var eventCount = 0;
    var outcome = AttemptOutcome.passed;
    String? primaryFailure;
    String? failureCode;
    SourceLocation? failureSource;
    String? failureOperation;
    Object? failureCause;
    StackTrace? failureStackTrace;
    final secondaryFailures = <String>[];
    final clock = Stopwatch()..start();
    // A wall-time limit is checked at every kernel boundary. Keeping the
    // deadline as a monotonic clock check means an in-flight runtime call is
    // allowed to unwind normally; the runtime is then closed by this kernel's
    // single finally block. This is deliberate: racing a Future and closing
    // the runtime while it is still executing can release Flutter resources
    // underneath the operation.

    // An operation is allowed to unwind before the kernel closes its runtime,
    // but the limit that was crossed while it was in flight must still win
    // over a late operation result.  Checking only at the top of the loop
    // used to turn an over-budget operation failure into a normal failure (or
    // let a cancelled operation continue into recovery).  This helper is
    // called after every awaited policy/runtime boundary so the outcome is
    // deterministic without racing an in-flight Flutter operation.
    AttemptOutcome? terminationAfterAwait() {
      if (cancellation?.isCancelled == true) {
        return AttemptOutcome.cancelled;
      }
      if (clock.elapsed >= limits.wallTime) {
        return AttemptOutcome.limitExceeded;
      }
      return null;
    }

    void applyTermination(AttemptOutcome termination) {
      outcome = termination;
      if (termination == AttemptOutcome.cancelled) {
        primaryFailure = 'Execution cancelled.';
        failureCode = 'cancelled';
      } else {
        primaryFailure = 'Execution limit exceeded.';
        failureCode = 'limitExceeded';
      }
    }

    Future<void> publishObserved(ExecutionEventKind kind,
        {String? nodeId,
        String? detail,
        String? operation,
        SourceLocation? source,
        int? stepIndex}) async {
      final event = ExecutionEvent(
        sequence: ++eventCount,
        kind: kind,
        nodeId: nodeId,
        detail: detail,
        operation: operation,
        source: source,
        stepIndex: stepIndex,
      );
      var index = 0;
      for (final subscriber in _subscribersByKind[event.kind]!) {
        try {
          await subscriber(event);
        } catch (error) {
          secondaryFailures.add('Event subscriber $index failed: $error');
        }
        index++;
      }
    }

    FutureOr<void> publish(ExecutionEventKind kind,
        {String? nodeId,
        String? detail,
        String? operation,
        SourceLocation? source,
        int? stepIndex}) {
      // Keep the no-observer path synchronous and allocation-free. Optional
      // evidence and report subscribers are omitted at construction time when
      // disabled; event accounting still remains observable through the
      // result. The observed path is isolated below so its async state machine
      // is never created for the normal execution path.
      if (eventSubscribers.isEmpty && eventSubscriptions.isEmpty) {
        eventCount++;
        return null;
      }
      return publishObserved(
        kind,
        nodeId: nodeId,
        detail: detail,
        operation: operation,
        source: source,
        stepIndex: stepIndex,
      );
    }

    final EvidenceBoundaryEventSource? boundarySource =
        runtime is EvidenceBoundaryEventSource
            ? runtime as EvidenceBoundaryEventSource
            : null;
    try {
      boundarySource?.bindEvidenceBoundaryEmitter(
        (stepIndex, stepType) => publish(
          ExecutionEventKind.evidenceBoundary,
          detail: stepType,
          stepIndex: stepIndex,
        ),
      );
      await publish(ExecutionEventKind.attemptStarted, nodeId: nodeId);
      while (true) {
        if (cancellation?.isCancelled == true) {
          outcome = AttemptOutcome.cancelled;
          primaryFailure = 'Execution cancelled.';
          failureCode = 'cancelled';
          break;
        }
        if (clock.elapsed >= limits.wallTime ||
            directiveCount >= limits.maxDirectives) {
          outcome = AttemptOutcome.limitExceeded;
          primaryFailure = 'Execution limit exceeded.';
          failureCode = 'limitExceeded';
          break;
        }

        final state = RunState(nodeId: nodeId, loopCounts: loopCounts);
        late ExecutionDirective directive;
        try {
          directive = await policy.next(state, view);
        } catch (error, stackTrace) {
          // A policy may finish by throwing after its attempt was cancelled
          // or its deadline elapsed. Preserve the same termination precedence
          // used for successful policy results and runtime calls.
          final termination = terminationAfterAwait();
          if (termination != null) {
            applyTermination(termination);
            break;
          }
          Error.throwWithStackTrace(error, stackTrace);
        }
        final policyTermination = terminationAfterAwait();
        if (policyTermination != null) {
          applyTermination(policyTermination);
          break;
        }
        directiveCount++;
        await publish(ExecutionEventKind.directiveSelected,
            nodeId: nodeId, detail: directive.runtimeType.toString());
        // Subscribers may cancel the attempt (or exhaust its wall-time
        // budget). Do not apply a directive after that awaited boundary: in
        // particular, doing so could start a UI mutation after cancellation.
        final directiveTermination = terminationAfterAwait();
        if (directiveTermination != null) {
          applyTermination(directiveTermination);
          break;
        }

        switch (directive) {
          case FinishDirective():
            if (plan.node(nodeId) is! EndNode) {
              throw StateError('Policy finished before the end node.');
            }
            break;
          case ObserveDirective(:final request):
            final node = plan.node(nodeId);
            if (node is! BranchNode ||
                request.level != ObservationLevel.minimal ||
                !sameInput(request.target, node.target)) {
              throw StateError('Observation is not valid at "$nodeId".');
            }
            try {
              view = await runtime.observe(request);
            } catch (error) {
              await publish(ExecutionEventKind.observationFailed,
                  nodeId: nodeId,
                  detail: error.toString(),
                  source: node.source);
              // Optional blocks recover from explicitly recoverable operation
              // failures. An observation exception has no recoverability
              // classification, so treating it as a hidden target could mask
              // a broken runtime and incorrectly pass the attempt.
              rethrow;
            }
            final observationTermination = terminationAfterAwait();
            if (observationTermination != null) {
              applyTermination(observationTermination);
              break;
            }
            if (!sameInput(view.target, node.target)) {
              throw StateError('Runtime observed a different target.');
            }
            if (view.level != request.level) {
              throw StateError(
                'Runtime returned observation level "${view.level.name}" '
                'for a "${request.level.name}" request.',
              );
            }
            await publish(ExecutionEventKind.observationCaptured,
                nodeId: nodeId, detail: '${view.revision}');
            continue;
          case StepBoundaryDirective(nodeId: final selectedId):
            final node = plan.node(state.nodeId);
            if (node is! StepBoundaryNode || node.id != selectedId) {
              throw StateError('Policy selected an invalid step boundary.');
            }
            await publish(
              node.started
                  ? ExecutionEventKind.stepStarted
                  : ExecutionEventKind.stepFinished,
              nodeId: node.id,
              stepIndex: node.stepIndex,
            );
            nodeId = node.next;
            view = null;
            continue;
          case MoveDirective(nodeId: final targetId, :final enteredLoop):
            final current = plan.node(state.nodeId);
            final allowed = switch (current) {
              BranchNode(:final whenVisible, :final whenHidden) =>
                view != null &&
                    sameInput(view.target, current.target) &&
                    targetId == (view.targetVisible ? whenVisible : whenHidden),
              LoopNode(:final body, :final next) =>
                targetId == body || targetId == next,
              RecoveryNode(:final next) => targetId == next,
              _ => false,
            };
            if (!allowed)
              throw StateError('Policy selected invalid plan edge.');
            if (enteredLoop != null) {
              if (current is! LoopNode ||
                  current.id != enteredLoop ||
                  targetId != current.body ||
                  (loopCounts[enteredLoop] ?? 0) >= current.times) {
                throw StateError('Policy selected invalid loop edge.');
              }
              if (loopEntryCount >= limits.maxLoopEntries) {
                outcome = AttemptOutcome.limitExceeded;
                primaryFailure = 'Loop limit exceeded.';
                failureCode = 'loopLimitExceeded';
                break;
              }
              loopEntryCount++;
              loopCounts[enteredLoop] = (loopCounts[enteredLoop] ?? 0) + 1;
            } else if (current is LoopNode && targetId == current.body) {
              throw StateError('Loop entry must be counted.');
            }
            if (current is LoopNode && targetId == current.next) {
              loopCounts.remove(current.id);
            }
            if (current is RecoveryNode) {
              for (final loopId in current.resetLoops) {
                loopCounts.remove(loopId);
              }
            }
            nodeId = targetId;
            view = null;
            continue;
          case ExecuteDirective(nodeId: final selectedId):
            final node = plan.node(state.nodeId);
            if (node is! OperationNode || node.id != selectedId) {
              throw StateError('Policy selected invalid operation.');
            }
            if (!runtime.capabilities.supports(node.operation)) {
              throw StateError(
                  'Runtime cannot execute "${node.operation.name}".');
            }
            if (operationCount >= limits.maxOperations) {
              outcome = AttemptOutcome.limitExceeded;
              primaryFailure = 'Operation limit exceeded.';
              failureCode = 'limitExceeded';
              failureSource = node.operation.source;
              failureOperation = node.operation.name;
              break;
            }
            operationCount++;
            await publish(ExecutionEventKind.operationStarted,
                nodeId: selectedId,
                operation: node.operation.name,
                source: node.operation.source);
            final startTermination = terminationAfterAwait();
            if (startTermination != null) {
              applyTermination(startTermination);
              failureSource = node.operation.source;
              failureOperation = node.operation.name;
              // Keep operation lifecycle events balanced even when a
              // subscriber cancels while receiving operationStarted.
              await publish(ExecutionEventKind.operationFinished,
                  nodeId: selectedId,
                  detail: primaryFailure,
                  operation: node.operation.name,
                  source: node.operation.source);
              break;
            }
            late OperationResult result;
            try {
              result = await runtime.execute(node.operation);
            } catch (error, stackTrace) {
              result = OperationResult.failure(
                error.toString(),
                errorCode: 'operationException',
                recoverable: false,
                cause: error,
                stackTrace: stackTrace,
              );
            }
            await publish(ExecutionEventKind.operationFinished,
                nodeId: selectedId,
                detail: result.error,
                operation: node.operation.name,
                source: node.operation.source);
            final operationTermination = terminationAfterAwait();
            if (operationTermination != null) {
              applyTermination(operationTermination);
              failureSource = node.operation.source;
              failureOperation = node.operation.name;
              break;
            }
            if (!result.succeeded) {
              if (node.onFailure != null && result.recoverable) {
                nodeId = node.onFailure!;
                view = null;
                continue;
              }
              outcome = AttemptOutcome.failed;
              primaryFailure = result.error;
              failureCode = result.errorCode;
              failureSource = node.operation.source;
              failureOperation = node.operation.name;
              failureCause = result.cause;
              failureStackTrace = result.stackTrace;
              break;
            }
            nodeId = node.next;
            view = null;
            continue;
        }
        break;
      }
    } catch (error, stackTrace) {
      outcome = AttemptOutcome.failed;
      primaryFailure ??= error.toString();
      failureCode ??= 'internalError';
      failureSource ??= switch (plan.node(nodeId)) {
        OperationNode(:final operation) => operation.source,
        BranchNode(:final source) => source,
        _ => null,
      };
      failureOperation ??= switch (plan.node(nodeId)) {
        OperationNode(:final operation) => operation.name,
        _ => null,
      };
      failureCause ??= error;
      failureStackTrace ??= stackTrace;
    } finally {
      try {
        boundarySource?.bindEvidenceBoundaryEmitter(null);
      } catch (error) {
        if (primaryFailure == null) {
          outcome = AttemptOutcome.failed;
          primaryFailure = 'Evidence boundary detach failed: $error';
          failureCode = 'cleanupFailed';
        } else {
          secondaryFailures.add('Evidence boundary detach failed: $error');
        }
      }
      try {
        await runtime.close();
      } catch (error) {
        if (primaryFailure == null) {
          outcome = AttemptOutcome.failed;
          primaryFailure = 'Runtime close failed: $error';
          failureCode = 'closeFailed';
        } else {
          secondaryFailures.add('Runtime close failed: $error');
        }
      }
      clock.stop();
      await publish(ExecutionEventKind.attemptFinished,
          nodeId: nodeId, detail: outcome.name);
    }
    return AttemptResult(
      outcome: outcome,
      operations: operationCount,
      events: eventCount,
      primaryFailure: primaryFailure,
      failureCode: failureCode,
      failureSource: failureSource,
      failureOperation: failureOperation,
      cause: failureCause,
      stackTrace: failureStackTrace,
      secondaryFailures: secondaryFailures,
    );
  }
}
