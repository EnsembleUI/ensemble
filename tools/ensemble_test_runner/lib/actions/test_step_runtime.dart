import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/event_driven_settler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owns Flutter frame delivery and bounded post-action settling.
///
/// Keeping this boundary separate from operation dispatch makes the timing
/// policy explicit. Callers decide *what* needs to happen; this class decides
/// how the Flutter tree and live application work are allowed to progress.
final class TestStepRuntime {
  TestStepRuntime({
    required this.tester,
    required this.context,
    required this.config,
  });

  final WidgetTester tester;
  final EnsembleTestContext context;
  final TestExecutionConfig config;

  Future<void> settle({Duration? timeout}) async {
    return RunnerBenchmark.async('execution', 'settle', () async {
      try {
        await _settleFromEvents(timeout: timeout ?? config.settleTimeout);
      } catch (error) {
        if (!error.toString().contains('timed out') &&
            !error.toString().contains('timeout')) {
          rethrow;
        }
        // Background streams can keep the event loop active after the UI has
        // reached a stable state. The bounded wait is therefore best effort.
      }
      await _drainFlutterDiagnostics();
      await yieldToLiveApiWork();
    });
  }

  Future<void> settleAfterAction() async {
    return RunnerBenchmark.async('execution', 'settleAfterAction', () async {
      try {
        await _settleUiFromEvents(timeout: config.actionSettleTimeout);
      } on FlutterError catch (error) {
        if (!error.toString().contains('timed out')) rethrow;
      }
      // A tap can launch an asynchronous app action (including navigation
      // callbacks that issue an API request first). Let that real async work
      // complete before the next step is evaluated, then settle its frames.
      // Keep this conditional so synchronous UI actions pay no extra wait.
      if (context.apiOverlay.hasPendingLiveCalls) {
        await yieldToLiveApiWork();
        try {
          await _settleUiFromEvents(timeout: config.actionSettleTimeout);
        } on FlutterError catch (error) {
          if (!error.toString().contains('timed out')) rethrow;
        }
      }
    });
  }

  Future<void> waitForCondition({
    required bool Function() condition,
    required Duration timeout,
  }) async {
    if (condition()) return;
    final elapsed = tester.binding.clock.stopwatch()..start();
    final pollInterval = config.waitPollInterval <= Duration.zero
        ? const Duration(milliseconds: 1)
        : config.waitPollInterval;
    while (elapsed.elapsed < timeout) {
      await tester.pump(pollInterval);
      await _drainFlutterDiagnostics();
      if (condition()) return;
    }
    throw FlutterError('wait for condition timed out');
  }

  Future<void> yieldToLiveApiWork() async {
    try {
      await _settleFromEvents(timeout: config.actionSettleTimeout);
    } on FlutterError catch (error) {
      if (!error.toString().contains('timed out')) rethrow;
    }
  }

  /// Advances a frame after yielding live work, preserving the guarded frame
  /// boundary required by route transitions and overlay updates.
  Future<void> pump({
    Duration? duration,
    EnginePhase phase = EnginePhase.sendSemanticsUpdate,
    required String label,
  }) async {
    // LiveTestWidgetsFlutterBinding.pump(duration) delays and builds in the
    // same turn. A separate yield avoids racing navigation callbacks with the
    // next build. The label is part of the benchmark contract.
    if (duration != null && duration > Duration.zero) {
      await liveDelay(duration);
      await tester.pump(null, phase);
      await tester.pump(null, phase);
    } else {
      await tester.pump(duration, phase);
    }
    await _drainFlutterDiagnostics();
  }

  void drainTransientFlutterDiagnostics() {
    _drainFlutterDiagnostics();
  }

  Future<void> liveDelay(Duration duration) async {
    if (duration <= Duration.zero) return;
    await tester.binding.delayed(duration);
  }

  /// Keeps the app's frame scheduler moving while a duration-based wait is
  /// active. A single live delay followed by a pump freezes frame callbacks,
  /// animations, and UI work for the entire interval in test bindings, unlike
  /// a foreground Flutter application that continues rendering.
  Future<void> pumpWhileWaiting(Duration duration) async {
    if (duration <= Duration.zero) {
      await tester.pump();
      await _drainFlutterDiagnostics();
      return;
    }

    var elapsed = Duration.zero;
    final frameInterval = config.waitPollInterval <= Duration.zero
        ? const Duration(milliseconds: 1)
        : config.waitPollInterval;
    while (elapsed < duration) {
      final remaining = duration - elapsed;
      final slice = remaining < frameInterval ? remaining : frameInterval;
      await tester.binding.delayed(slice);
      await tester.pump();
      await tester.pump();
      await _drainFlutterDiagnostics();
      elapsed += slice;
    }
  }

  Future<void> _settleFromEvents({required Duration timeout}) async {
    await EventDrivenSettler(
      tester: tester,
      hasExternalWork: () => context.apiOverlay.hasPendingLiveCalls,
      waitForExternalWork: context.apiOverlay.waitForLiveCalls,
      externalWorkPollTimeout: config.waitPollInterval,
      activeFrameDuration: config.settleStepDuration,
      onPump: drainTransientFlutterDiagnostics,
    ).settle(timeout: timeout);
  }

  Future<void> _settleUiFromEvents({required Duration timeout}) async {
    await EventDrivenSettler(
      tester: tester,
      activeFrameDuration: config.settleStepDuration,
      onPump: drainTransientFlutterDiagnostics,
    ).settle(timeout: timeout);
  }

  Future<void> _drainFlutterDiagnostics() async {
    while (tester.takeException() != null) {}
  }
}
