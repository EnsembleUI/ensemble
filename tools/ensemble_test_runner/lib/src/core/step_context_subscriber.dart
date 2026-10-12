import 'dart:async';

import 'kernel.dart';

/// Publishes the authored step currently active at the execution boundary.
///
/// API and console evidence use this value to attribute records to a top-level
/// step. Keeping the update in an ordered subscriber makes standalone and
/// hosted entry paths use the same boundary and prevents their compatibility
/// callbacks from drifting apart.
final class StepContextSubscriber {
  StepContextSubscriber({
    required void Function(int) onStepStarted,
    void Function(int)? onStepFinished,
  })  : _onStepStarted = onStepStarted,
        _onStepFinished = onStepFinished;

  final void Function(int) _onStepStarted;
  final void Function(int)? _onStepFinished;

  FutureOr<void> call(ExecutionEvent event) {
    final index = event.stepIndex;
    if (index == null) return null;
    if (event.kind == ExecutionEventKind.stepStarted) {
      _onStepStarted(index);
    } else if (event.kind == ExecutionEventKind.stepFinished) {
      _onStepFinished?.call(index);
    }
  }
}
