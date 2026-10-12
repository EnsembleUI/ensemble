import 'dart:async';

import 'kernel.dart';

/// Dispatches authored-step lifecycle work from ordered kernel events.
///
/// Adapter callbacks remain outside the kernel, while this subscriber keeps
/// their start and finish work on the same event path as timing and evidence.
/// Errors are handed back to the adapter so it can cancel the attempt and
/// project the original failure through its existing result path.
final class StepBoundarySubscriber {
  StepBoundarySubscriber({
    required FutureOr<void> Function(int stepIndex) onStarted,
    required FutureOr<void> Function(int stepIndex) onFinished,
    required void Function(Object error, StackTrace stackTrace) onError,
  })  : _onStarted = onStarted,
        _onFinished = onFinished,
        _onError = onError;

  final FutureOr<void> Function(int) _onStarted;
  final FutureOr<void> Function(int) _onFinished;
  final void Function(Object, StackTrace) _onError;

  FutureOr<void> call(ExecutionEvent event) {
    final callback = switch (event.kind) {
      ExecutionEventKind.stepStarted => _onStarted,
      ExecutionEventKind.stepFinished => _onFinished,
      _ => null,
    };
    final stepIndex = event.stepIndex;
    if (callback == null || stepIndex == null) return null;
    return _run(callback, stepIndex);
  }

  Future<void> _run(
    FutureOr<void> Function(int) callback,
    int stepIndex,
  ) async {
    try {
      await callback(stepIndex);
    } catch (error, stackTrace) {
      _onError(error, stackTrace);
    }
  }
}
