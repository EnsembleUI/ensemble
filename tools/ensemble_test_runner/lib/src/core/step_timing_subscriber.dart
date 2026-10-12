import 'dart:async';

import 'package:ensemble_test_runner/src/core/kernel.dart';

/// Measures authored test step spans from the kernel's ordered boundaries.
///
/// Timing failures are surfaced by throwing [StateError]. The execution kernel
/// records subscriber failures as secondary diagnostics and continues delivery.
final class StepTimingSubscriber {
  StepTimingSubscriber({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final Map<int, DateTime> _startedAt = {};
  final Map<int, String> _startTimes = {};
  final Map<int, int> _durationsMs = {};

  FutureOr<void> call(ExecutionEvent event) {
    final index = event.stepIndex;
    if (index == null) return null;
    switch (event.kind) {
      case ExecutionEventKind.stepStarted:
        if (_startedAt.containsKey(index)) {
          return Future<void>.error(
            StateError('Step $index started before its previous span ended.'),
            StackTrace.current,
          );
        }
        final start = _now();
        _startedAt[index] = start;
        _startTimes[index] = start.toIso8601String();
      case ExecutionEventKind.stepFinished:
        final start = _startedAt.remove(index);
        if (start == null) {
          return Future<void>.error(
            StateError('Step $index finished without a start boundary.'),
            StackTrace.current,
          );
        }
        _durationsMs[index] = _now().difference(start).inMilliseconds;
      default:
        break;
    }
  }

  String? startTimeFor(int stepIndex) => _startTimes[stepIndex];

  int? durationFor(int stepIndex) => _durationsMs[stepIndex];

  int elapsedMsFor(int stepIndex, {DateTime? at}) {
    final duration = _durationsMs[stepIndex];
    if (duration != null) return duration;
    final start = _startedAt[stepIndex];
    return start == null ? 0 : (at ?? _now()).difference(start).inMilliseconds;
  }
}
