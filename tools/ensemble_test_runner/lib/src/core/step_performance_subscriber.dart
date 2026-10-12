import 'dart:async';

import 'kernel.dart';

/// Stages performance evidence at the ordered end of an authored step.
///
/// The subscriber deliberately knows nothing about frames, screens, or
/// report formats. The application entry supplies the capture callback, while
/// the kernel guarantees that it runs once for each valid `stepFinished`
/// boundary and before legacy event compatibility callbacks. The separate
/// [flush] operation lets an entry finish its boundary cleanup first, keeping
/// the marker's frame range identical to the legacy lifecycle.
final class StepPerformanceSubscriber {
  StepPerformanceSubscriber({required FutureOr<void> Function(int) capture})
      : _capture = capture;

  final FutureOr<void> Function(int) _capture;
  final Set<int> _pending = <int>{};
  final Map<int, Future<void>> _inFlight = <int, Future<void>>{};

  /// Returns synchronously for events that do not end a step. This subscriber
  /// runs for every kernel event, so avoiding an async state machine on the
  /// common path keeps instrumentation out of the normal execution cost.
  FutureOr<void> call(ExecutionEvent event) {
    if (event.kind != ExecutionEventKind.stepFinished) return null;
    final stepIndex = event.stepIndex;
    if (stepIndex == null) return null;
    _pending.add(stepIndex);
  }

  /// Publishes a staged marker after the entry has completed boundary work.
  Future<void> flush(int stepIndex) {
    // A boundary can be revisited by failure cleanup while the first evidence
    // write is still unwinding. Share that write instead of capturing twice.
    final inFlight = _inFlight[stepIndex];
    if (inFlight != null) return inFlight;
    if (!_pending.contains(stepIndex)) return Future<void>.value();

    // Keep the marker pending until capture succeeds. A failed evidence sink
    // can therefore be retried by the owning cleanup path instead of silently
    // losing the only performance marker for the step.
    final future = Future<void>.sync(() => _capture(stepIndex)).then<void>(
      (_) {
        _pending.remove(stepIndex);
      },
    );
    final tracked = future.whenComplete(() {
      _inFlight.remove(stepIndex);
    });
    _inFlight[stepIndex] = tracked;
    return tracked;
  }
}
