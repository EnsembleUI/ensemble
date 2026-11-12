import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Settles Flutter work from observable event signals instead of scanning a
/// fixed frame cadence. The boundary is shared by execution, observation, and
/// fixture setup so each path has the same bounded idle semantics.
final class EventDrivenSettler {
  EventDrivenSettler({
    required this.tester,
    this.hasExternalWork = _noExternalWork,
    this.waitForExternalWork = _waitForNoExternalWork,
    this.externalWorkPollTimeout = const Duration(milliseconds: 100),
    this.activeFrameDuration = const Duration(milliseconds: 100),
    this.graceFrameDuration = const Duration(milliseconds: 16),
    this.onPump,
  });

  final WidgetTester tester;
  final bool Function() hasExternalWork;
  final Future<void> Function() waitForExternalWork;
  final Duration externalWorkPollTimeout;
  final Duration activeFrameDuration;
  final Duration graceFrameDuration;
  final FutureOr<void> Function()? onPump;

  Future<void> settle({required Duration timeout}) async {
    final timeoutClock = tester.binding.clock.stopwatch()..start();
    var idleTurns = 0;
    var graceFrameApplied = false;

    await _pump();
    // The initial pump flushes callbacks queued by the preceding operation.
    // If it leaves neither external work nor a transient Flutter callback,
    // another grace frame cannot reveal useful state and only adds latency to
    // every already-idle action and screenshot boundary.
    if (!hasExternalWork() && tester.binding.transientCallbackCount == 0) {
      return;
    }
    while (timeoutClock.elapsed < timeout) {
      final hasFrameWork = tester.binding.transientCallbackCount > 0;
      if (!hasExternalWork() && !hasFrameWork) {
        if (!graceFrameApplied) {
          graceFrameApplied = true;
          final remaining = timeout - timeoutClock.elapsed;
          if (remaining <= Duration.zero) break;
          await _pump(_boundedDuration(graceFrameDuration, remaining));
          idleTurns = 0;
          continue;
        }
        await _pump();
        if (!hasExternalWork() && tester.binding.transientCallbackCount == 0) {
          idleTurns++;
          if (idleTurns >= 2) return;
        } else {
          idleTurns = 0;
        }
        continue;
      }

      idleTurns = 0;
      if (hasExternalWork()) {
        // Advance one guarded frame before awaiting an external completion
        // signal. Live bindings may only deliver that completion from work
        // scheduled by a frame, so awaiting first can deadlock the wait.
        var remaining = timeout - timeoutClock.elapsed;
        if (remaining <= Duration.zero) break;
        await _pump(_boundedDuration(graceFrameDuration, remaining));
        if (!hasExternalWork()) continue;
        remaining = timeout - timeoutClock.elapsed;
        if (remaining <= Duration.zero) break;
        // Let the owner signal completion before advancing another full
        // active frame. This avoids adding an arbitrary 100 ms to every
        // settle while still retaining a bounded pump when the signal is
        // unavailable or misbehaves.
        final completed = await _waitForExternalWorkBounded(
          timeout: _boundedDuration(
            externalWorkPollTimeout,
            remaining,
          ),
        );
        if (completed) {
          remaining = timeout - timeoutClock.elapsed;
          if (remaining <= Duration.zero) break;
          await _pump(_boundedDuration(graceFrameDuration, remaining));
          continue;
        }
      }
      final remaining = timeout - timeoutClock.elapsed;
      if (remaining <= Duration.zero) break;
      await _pump(_boundedDuration(activeFrameDuration, remaining));
    }
    throw FlutterError('settle until idle timed out');
  }

  /// Waits for an externally observable condition while advancing only
  /// bounded event-driven frames. This is used for startup targets whose
  /// availability is the synchronization contract, rather than waiting for
  /// an arbitrary number of fixed-duration pumps.
  Future<void> waitFor({
    required bool Function() condition,
    required Duration timeout,
  }) async {
    // Conditions are often satisfied by the preceding action or event
    // callback. Avoid advancing a frame when no synchronization is needed.
    if (condition()) return;

    // Use the binding clock so time spent awaiting external work counts
    // against the same timeout as frame advancement. Counting only requested
    // pump durations let the external-work poll and following frame each
    // consume time, nearly doubling waits while a live call remained pending.
    final timeoutClock = tester.binding.clock.stopwatch()..start();

    await _pump();
    while (timeoutClock.elapsed < timeout) {
      if (condition()) return;

      final hasFrameWork = tester.binding.transientCallbackCount > 0;
      final hasExternalWork = this.hasExternalWork();
      if (hasExternalWork) {
        final remaining = timeout - timeoutClock.elapsed;
        await _pump(_boundedDuration(graceFrameDuration, remaining));
        if (!this.hasExternalWork()) {
          if (condition()) return;
          continue;
        }
        if (timeoutClock.elapsed <= timeout && condition()) return;
        final remainingAfterPump = timeout - timeoutClock.elapsed;
        if (remainingAfterPump <= Duration.zero) break;
        final completed = await _waitForExternalWorkBounded(
          timeout: _boundedDuration(
            externalWorkPollTimeout,
            remainingAfterPump,
          ),
        );
        if (completed) {
          await _pump();
        } else {
          final remainingAfterWait = timeout - timeoutClock.elapsed;
          if (remainingAfterWait <= Duration.zero) break;
          await _pump(
            _boundedDuration(activeFrameDuration, remainingAfterWait),
          );
        }
        if (timeoutClock.elapsed <= timeout && condition()) return;
        continue;
      }

      final remaining = timeout - timeoutClock.elapsed;
      final frameDuration =
          hasFrameWork ? activeFrameDuration : graceFrameDuration;
      await _pump(_boundedDuration(frameDuration, remaining));
      if (condition()) return;
    }
    throw FlutterError('wait for condition timed out');
  }

  Future<void> _pump([Duration? duration]) async {
    await tester.pump(duration, EnginePhase.sendSemanticsUpdate);
    await onPump?.call();
  }

  Future<bool> _waitForExternalWorkBounded({required Duration timeout}) async {
    var completed = false;
    var succeeded = false;
    final completion = Completer<void>();
    waitForExternalWork().then<void>(
      (_) {
        succeeded = true;
        completed = true;
        completion.complete();
      },
      onError: (Object _, StackTrace __) {
        completed = true;
        completion.complete();
      },
    );

    // Flush already-resolved futures before asking the widget binding to
    // advance its timeout clock. Fake bindings advance that clock eagerly;
    // racing an immediate completion against a timeout first would charge
    // the full poll interval even when no wait was needed.
    await Future<void>.value();
    if (completed) return succeeded;

    // Advance the test clock instead of awaiting a timer: widget tests run in
    // fake async, so a timer cannot fire while this method is awaiting it.
    // Pumping also gives the external completion signal a chance to run.
    await _pump(timeout);
    await Future<void>.value();
    return completed && succeeded;
  }

  Duration _boundedDuration(Duration requested, Duration remaining) =>
      requested < remaining ? requested : remaining;

  static bool _noExternalWork() => false;

  static Future<void> _waitForNoExternalWork() async {}
}
