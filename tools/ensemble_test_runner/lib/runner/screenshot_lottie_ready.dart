import 'package:ensemble/widget/lottie/lottie.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:flutter_test/flutter_test.dart';

/// Default budget for waiting on Lottie composition load before a screenshot.
const Duration kScreenshotLottieReadyTimeout = Duration(seconds: 2);

/// Representative progress for contact-sheet frames.
///
/// Several inhome Lotties (e.g. `Experia_modem_connect_*`) only draw a solid
/// Grey/Darkmode background at progress 0 — devices/cables animate in later.
/// Seeking here makes screenshots show the intended illustration.
const double kScreenshotLottieProgress = 0.45;

/// Whether every on-screen [EnsembleLottie] with a source has finished loading.
///
/// Empty-source Lotties are treated as ready (nothing to decode). Widgets that
/// still await `onLoaded` → [LottieController.initializeLottieController] are
/// not ready; capturing then yields a blank box when `placeholderColor` is
/// transparent.
bool areVisibleLottiesReady(WidgetTester tester) {
  for (final element in find.byType(EnsembleLottie).evaluate()) {
    final widget = element.widget;
    if (widget is! EnsembleLottie) continue;
    final controller = widget.controller;
    if (controller.source.trim().isEmpty) continue;
    if (!controller.compositionReady) return false;
  }
  return true;
}

/// Holds each loaded Lottie on a mid-animation frame for screenshot capture.
///
/// Safe for the live test UI: [AnimationController.repeat] continues from the
/// new value on subsequent ticks.
void seekVisibleLottiesForScreenshot(
  WidgetTester tester, {
  double progress = kScreenshotLottieProgress,
}) {
  final clamped = progress.clamp(0.0, 1.0);
  for (final element in find.byType(EnsembleLottie).evaluate()) {
    final widget = element.widget;
    if (widget is! EnsembleLottie) continue;
    final animation = widget.controller.lottieController;
    if (animation == null || animation.duration == null) continue;
    animation.value = clamped;
  }
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
  final stopwatch = Stopwatch()..start();
  while (stopwatch.elapsed < timeout) {
    if (areVisibleLottiesReady(tester)) {
      seekVisibleLottiesForScreenshot(tester, progress: progress);
      await tester.pump();
      return;
    }
    await tester.pump(pollInterval);
    await _yieldToRealAsyncWork(tester);
  }
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
