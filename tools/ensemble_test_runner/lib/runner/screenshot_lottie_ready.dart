import 'dart:async';

import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Advances the short screenshot transition window while avoiding a second
/// frame when the binding has no scheduled or transient work left.
Future<void> pumpScreenshotStabilityFrames(
  WidgetTester tester, {
  Duration duration = const Duration(milliseconds: 50),
  FutureOr<void> Function()? onPump,
}) async {
  await tester.pump(duration);
  await onPump?.call();
  if (!tester.binding.hasScheduledFrame &&
      tester.binding.transientCallbackCount == 0) {
    return;
  }
  await tester.pump(duration);
  await onPump?.call();
}

/// Default budget for waiting on Lottie composition load before a screenshot.
const Duration kScreenshotLottieReadyTimeout = Duration(seconds: 2);

/// Representative progress for contact-sheet frames.
///
/// Some app illustrations only draw a solid background at progress 0;
/// devices and cables animate in later.
/// Seeking here makes screenshots show the intended illustration.
const double kScreenshotLottieProgress = 0.45;

/// Whether every on-screen [EnsembleLottie] with a source has finished loading.
///
/// Empty-source Lotties are treated as ready (nothing to decode). Widgets that
/// still await `onLoaded` → [LottieController.initializeLottieController] are
/// not ready; capturing then yields a blank box when `placeholderColor` is
/// transparent.
bool areVisibleLottiesReady(WidgetTester tester) {
  return RunnerBenchmark.sync('screenshot', 'areVisibleLottiesReady', () {
    for (final element in find.byType(EnsembleLottie).evaluate()) {
      if (!_isVisibleOnScreen(tester, element)) continue;
      final widget = element.widget;
      if (widget is! EnsembleLottie) continue;
      final controller = widget.controller;
      if (controller.source.trim().isEmpty) continue;
      if (!controller.compositionReady) return false;
    }
    return true;
  });
}

/// Holds each loaded Lottie on a mid-animation frame for screenshot capture.
///
/// Safe for the live test UI: [AnimationController.repeat] continues from the
/// new value on subsequent ticks.
void seekVisibleLottiesForScreenshot(
  WidgetTester tester, {
  double progress = kScreenshotLottieProgress,
}) {
  return RunnerBenchmark.sync('screenshot', 'seekVisibleLottiesForScreenshot',
      () {
    final clamped = progress.clamp(0.0, 1.0);
    for (final element in find.byType(EnsembleLottie).evaluate()) {
      if (!_isVisibleOnScreen(tester, element)) continue;
      final widget = element.widget;
      if (widget is! EnsembleLottie) continue;
      final animation = widget.controller.lottieController;
      if (animation == null || animation.duration == null) continue;
      animation.value = clamped;
    }
  });
}

bool _isVisibleOnScreen(WidgetTester tester, Element element) {
  final renderObject = element.renderObject;
  if (renderObject is! RenderBox ||
      !renderObject.attached ||
      !renderObject.hasSize ||
      renderObject.size.isEmpty) {
    return false;
  }

  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  if (rect.isEmpty) return false;

  final view = tester.view;
  final screenSize = view.physicalSize / view.devicePixelRatio;
  final screenRect = Offset.zero & screenSize;
  return rect.overlaps(screenRect);
}

/// Best-effort wait until visible Lotties have compositions ready to paint,
/// then seek to [kScreenshotLottieProgress] so intro-only frames are skipped.
///
/// Yields to real async work (asset decode) via [LiveAsyncCallSupport] /
/// [WidgetTester.runAsync]. Times out quietly — screenshot capture must never
/// fail the test.
Future<void> waitForVisibleLottiesReady(
  WidgetTester tester, {
  Duration timeout = kScreenshotLottieReadyTimeout,
  Duration pollInterval = const Duration(milliseconds: 50),
  double progress = kScreenshotLottieProgress,
}) async {
  return await RunnerBenchmark.async('screenshot', 'waitForVisibleLottiesReady',
      () async {
    // Count the same virtual frame durations that are handed to the binding.
    // A wall-clock stopwatch can spin indefinitely under fake-async tests when
    // a frame pump advances virtual time without consuming wall time.
    final frameInterval = pollInterval <= Duration.zero
        ? const Duration(milliseconds: 1)
        : pollInterval;
    var elapsed = Duration.zero;
    while (elapsed < timeout) {
      if (areVisibleLottiesReady(tester)) {
        seekVisibleLottiesForScreenshot(tester, progress: progress);
        await tester.pump();
        return;
      }
      await tester.pump(frameInterval);
      elapsed += frameInterval;
      // Screenshot readiness is best effort. If a live API call owns the
      // serialized runAsync lane, queued asset work cannot make progress and
      // waiting behind it would bypass this method's timeout entirely.
      if (LiveAsyncCallSupport.hasPendingLiveCalls) return;
      await _yieldToRealAsyncWork(tester);
    }
  });
}

Future<void> _yieldToRealAsyncWork(WidgetTester tester) async {
  Future<void> yieldOnce() async {
    await Future<void>.delayed(Duration.zero);
  }

  if (LiveAsyncCallSupport.runner != null) {
    await LiveAsyncCallSupport.runUntracked<void>(yieldOnce);
  } else {
    await tester.runAsync(yieldOnce);
  }
}
