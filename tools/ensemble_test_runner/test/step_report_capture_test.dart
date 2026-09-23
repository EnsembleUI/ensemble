import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('captureStepReportArtifacts skips observer when screenshot fails',
      () async {
    var observeCalls = 0;
    final didCapture = await captureStepReportArtifacts(
      captureScreenshot: () async => false,
      captureObserver: () async {
        observeCalls++;
      },
    );
    expect(didCapture, isFalse);
    expect(observeCalls, 0);
  });

  test('captureStepReportArtifacts runs observer only after a kept shot',
      () async {
    var observeCalls = 0;
    final didCapture = await captureStepReportArtifacts(
      captureScreenshot: () async => true,
      captureObserver: () async {
        observeCalls++;
      },
    );
    expect(didCapture, isTrue);
    expect(observeCalls, 1);
  });

  test('beforeAction policy enables paint wait and contrast gate', () {
    final options = StepScreenshotOptions.beforeAction();
    expect(options.waitForTarget, isTrue);
    expect(options.requireVisibleActionHighlight, isTrue);
    expect(options.waitForLottie, isFalse);
    expect(options.stabilize, isTrue);
    expect(options.allowObserveWhileQueueBusy, isFalse);
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
  });
}
