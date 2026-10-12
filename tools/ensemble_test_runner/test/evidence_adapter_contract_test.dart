import 'package:ensemble_test_runner/entry/application_test_entry_support.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/runner/screenshot_capture_failure.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_subscriber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('navigation evidence keeps adapter-specific capture boundaries',
      () async {
    var visibleRoute = 'Target';
    final standaloneFrames = <String>[];
    final hostFrames = <String>[];
    final standalone = StepEvidenceSubscriber(
      capture: (_) async {
        standaloneFrames.add('finished:$visibleRoute');
        return true;
      },
      captureBeforeMutation: (event) async {
        if (StepEvidencePolicy.classify(event.detail) !=
            StepEvidenceBoundary.navigation) {
          return false;
        }
        standaloneFrames.add('matched:$visibleRoute');
        return true;
      },
    );
    final host = StepEvidenceSubscriber(
      capture: (_) async {
        hostFrames.add('finished:$visibleRoute');
        return true;
      },
      captureBeforeMutation: (event) async {
        // Host report evidence waits for a completed route frame.
        if (StepEvidencePolicy.classify(event.detail) ==
            StepEvidenceBoundary.navigation) return false;
        hostFrames.add('matched:$visibleRoute');
        return true;
      },
    );
    const matched = ExecutionEvent(
      sequence: 1,
      kind: ExecutionEventKind.evidenceBoundary,
      detail: 'waitForNavigation',
      stepIndex: 0,
    );

    await standalone.call(matched);
    await host.call(matched);
    visibleRoute = 'Final';
    const finished = ExecutionEvent(
      sequence: 2,
      kind: ExecutionEventKind.stepFinished,
      stepIndex: 0,
    );
    await standalone.call(finished);
    await host.call(finished);

    expect(standaloneFrames, ['matched:Target']);
    expect(hostFrames, ['finished:Final']);
  });

  test('capture failures retain adapter-specific reporting policy', () {
    final hostFailures = <TestFailureDetails>[];
    final known = StateError('screenshot requires a painted render view.');
    recordHostScreenshotCaptureFailure(
      error: known,
      secondaryFailures: hostFailures,
    );
    expect(hostFailures, isEmpty);

    final unexpected = StateError('encoding failed');
    recordHostScreenshotCaptureFailure(
      error: unexpected,
      secondaryFailures: hostFailures,
    );
    expect(hostFailures, hasLength(1));
    expect(hostFailures.single.message, 'Screenshot failed: $unexpected');
    expect(hostFailures.single.phase, 'screenshot');

    expect(
      classifyScreenshotCaptureFailure(known),
      ScreenshotCaptureFailureKind.unpaintedRenderView,
    );
    expect(
      classifyScreenshotCaptureFailure(StateError('toImageSync failed')),
      ScreenshotCaptureFailureKind.renderCapture,
    );
    expect(
      classifyScreenshotCaptureFailure(unexpected),
      ScreenshotCaptureFailureKind.other,
    );

    final context = EnsembleTestContext.fromTestCase(
      const EnsembleTestCase(id: 'capture-error', steps: []),
    );
    const step = TestStep(type: 'tap', args: {'id': 'continue'});
    logStandaloneScreenshotCaptureFailure(
      context: context,
      step: step,
      stepIndex: 0,
      error: known,
    );
    expect(
      context.logger.logs,
      contains(contains('Screenshot capture skipped for step 1 (tap)')),
    );
    expect(context.logger.logs.single, contains(known.toString()));
    expect(context.logger.logs.single, contains('unpaintedRenderView'));
  });
}
