import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/session/observation/observation_options.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capture result reflects whether a screenshot frame was added',
      () async {
    final didCapture = await captureStepReportArtifacts(
      captureScreenshot: () async => false,
    );
    expect(didCapture, isFalse);
  });

  test('capture result reports a kept screenshot frame', () async {
    final didCapture = await captureStepReportArtifacts(
      captureScreenshot: () async => true,
    );
    expect(didCapture, isTrue);
  });

  test('disabled capture skips the screenshot callback', () async {
    var screenshotCalls = 0;
    final didCapture = await captureStepReportArtifacts(
      enabled: false,
      captureScreenshot: () async {
        screenshotCalls++;
        return true;
      },
    );
    expect(didCapture, isFalse);
    expect(screenshotCalls, 0);
  });

  test('beforeAction keeps required taps without the contrast gate', () {
    final options = StepScreenshotOptions.beforeAction();
    expect(options.waitForTarget, isFalse);
    expect(options.requireVisibleActionHighlight, isFalse);
    expect(options.waitForLottie, isFalse);
    expect(options.stabilize, isTrue);
    expect(options.allowObserveWhileQueueBusy, isFalse);
    expect(options.observationDetail, ObservationDetailLevel.standard);
  });

  test('beforeAction optional taps keep the contrast gate', () {
    final options = StepScreenshotOptions.beforeAction(
      requireVisibleActionHighlight: true,
    );
    expect(options.requireVisibleActionHighlight, isTrue);
    expect(options.waitForTarget, isFalse);
  });

  test('beforeAction can reuse a tap target already resolved by execution', () {
    final options = StepScreenshotOptions.beforeAction(
      targetAlreadyResolved: true,
    );
    expect(options.ensureTargetVisible, isFalse);
    expect(options.pumpBeforeCapture, isFalse);
    expect(options.stabilize, isFalse);
    expect(options.waitForTarget, isFalse);
  });

  test('mid-wait policies allow Observer while the leaf queue is busy', () {
    expect(
      StepScreenshotOptions.waitForTextMatched().allowObserveWhileQueueBusy,
      isTrue,
    );
    expect(
      StepScreenshotOptions.waitForNavigationMatched()
          .allowObserveWhileQueueBusy,
      isTrue,
    );
  });

  test('matched text evidence does not advance or reposition the UI', () {
    final options = StepScreenshotOptions.waitForTextMatched();
    expect(options.pumpBeforeCapture, isFalse);
    expect(options.ensureTargetVisible, isFalse);
    expect(options.stabilize, isFalse);
  });

  test('afterCondition disables long Lottie wait for waitForNavigation', () {
    const step = TestStep(type: 'waitForNavigation', args: {'screen': 'Home'});
    final options = StepScreenshotOptions.afterCondition(step);
    expect(options.waitForLottie, isFalse);
  });

  test('onFailure freezes without pumps or target waits', () {
    final options = StepScreenshotOptions.onFailure();
    expect(options.stabilize, isFalse);
    expect(options.waitForTarget, isFalse);
    expect(options.forFailure, isTrue);
    expect(options.allowObserveWhileQueueBusy, isTrue);
    expect(options.observationDetail, ObservationDetailLevel.diagnostic);
  });
}
