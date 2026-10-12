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
        await _settleFromEvents(timeout: config.actionSettleTimeout);
      } on FlutterError catch (error) {
        if (!error.toString().contains('timed out')) rethrow;
      }
      // The event settler already observes live calls. Only perform the
      // compatibility yield when a call is still pending; an unconditional
      // second bounded settle added up to another action timeout to every
      // interaction without changing the settled UI.
      if (context.apiOverlay.hasPendingLiveCalls) {
        await yieldToLiveApiWork();
      }
    });
  }

  Future<void> waitForCondition({
    required bool Function() condition,
    required Duration timeout,
  }) =>
      EventDrivenSettler(
        tester: tester,
        hasExternalWork: () => context.apiOverlay.hasPendingLiveCalls,
        waitForExternalWork: context.apiOverlay.waitForLiveCalls,
        externalWorkPollTimeout: config.waitPollInterval,
        activeFrameDuration: config.settleStepDuration,
        onPump: _drainFlutterDiagnostics,
      ).waitFor(condition: condition, timeout: timeout);

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

  Future<void> _drainFlutterDiagnostics() async {
    while (tester.takeException() != null) {}
  }
}
