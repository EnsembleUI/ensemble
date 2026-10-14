import 'dart:convert';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/entry/application_test_entry_support.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/src/core/execution_kernel_runner.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';
import 'package:ensemble_test_runner/src/core/step_context_subscriber.dart';
import 'package:ensemble_test_runner/src/runtime/compiled_plan.dart';
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_policy.dart';
import 'package:ensemble_test_runner/src/runtime/step_evidence_subscriber.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hosted and standalone adapters emit matching operation evidence frames',
    (tester) async {
      final hosted = await _runAdapter(tester, _EvidenceAdapter.hosted);
      final standalone = await _runAdapter(tester, _EvidenceAdapter.standalone);

      expect(hosted.events, standalone.events);
      expect(hosted.captures, hasLength(3));
      expect(standalone.captures, hasLength(3));
      expect(hosted.events, contains('evidenceBoundary:1:tap'));
      for (var index = 0; index < hosted.captures.length; index++) {
        final hostCapture = hosted.captures[index];
        final standaloneCapture = standalone.captures[index];
        expect(hostCapture.stepIndex, standaloneCapture.stepIndex);
        expect(hostCapture.label, standaloneCapture.label);
        expect(hostCapture.observationJson, standaloneCapture.observationJson);
        expect(
          listEquals(hostCapture.rgba, standaloneCapture.rgba),
          isTrue,
          reason: 'screenshot pixels differ at step ${hostCapture.stepIndex}; '
              '${_pixelDiffCount(hostCapture.rgba, standaloneCapture.rgba)} '
              'channels differ (${hostCapture.rgba.length} vs '
              '${standaloneCapture.rgba.length})',
        );
      }
      expect(
        hosted.captures.map((capture) => capture.stepIndex),
        [0, 1, 2],
      );
      expect(hosted.captures[0].observationJson, contains('Before'));
      expect(hosted.captures[1].observationJson, contains('Before'));
      expect(hosted.captures[2].observationJson, contains('After'));
    },
  );
}

int _pixelDiffCount(Uint8List left, Uint8List right) {
  if (left.length != right.length) return -1;
  var different = 0;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) different++;
  }
  return different;
}

Future<_AdapterResult> _runAdapter(
  WidgetTester tester,
  _EvidenceAdapter adapter,
) async {
  tester.binding.handlePointerEvent(
    const PointerExitEvent(position: Offset(-1, -1)),
  );
  await tester.pumpWidget(_OperationFixture(key: UniqueKey()));
  await tester.pumpAndSettle();
  expect(find.text('Before'), findsOneWidget,
      reason: 'fixture starts in the pre-action state for ${adapter.name}');
  final testCase = EnsembleTestParser.parseString('''
id: evidence_adapter_parity
steps:
  - expectText: {text: Before}
  - tap: {id: continue_action}
  - waitForText: {text: After}
''');
  final context = EnsembleTestContext.fromTestCase(
    testCase,
    config: const EnsembleTestConfig(
      screenshots: ScreenshotConfig(enabled: true),
    ),
  );
  final session = LocalTestExecutionSession.attach(
    tester: tester,
    context: context,
    sessionId: '${adapter.name}-evidence-parity',
  );
  final visuals = TestVisualArtifacts(
    screenshotSheets: () => null,
    drainFlutterExceptions: (tester) {
      while (tester.takeException() != null) {}
    },
  );
  final events = <String>[];
  final secondaryFailures = <TestFailureDetails>[];

  Future<bool> captureCompleted(int stepIndex) async {
    final step = testCase.steps[stepIndex];
    if (adapter == _EvidenceAdapter.hosted) {
      return captureHostStepReportArtifactsSafely(
        tester: tester,
        context: context,
        session: session,
        step: step,
        stepIndex: stepIndex,
        secondaryFailures: secondaryFailures,
      );
    }
    return visuals.captureStepArtifacts(
      executor: session.executor,
      step: step,
      stepIndex: stepIndex,
      options: StepScreenshotOptions.afterCondition(step),
    );
  }

  Future<bool> captureBoundary(ExecutionEvent event) async {
    final stepIndex = event.stepIndex!;
    final step = testCase.steps[stepIndex];
    final boundary = StepEvidencePolicy.classify(event.detail);
    if (boundary == StepEvidenceBoundary.navigation) return false;

    if (adapter == _EvidenceAdapter.hosted) {
      return captureHostStepReportArtifactsSafely(
        tester: tester,
        context: context,
        session: session,
        step: step,
        stepIndex: stepIndex,
        secondaryFailures: secondaryFailures,
        atCurrentFrame: true,
      );
    }

    switch (boundary) {
      case StepEvidenceBoundary.condition:
        return visuals.captureStepArtifacts(
          executor: session.executor,
          step: step,
          stepIndex: stepIndex,
          options: StepScreenshotOptions.matchedCondition(),
        );
      case StepEvidenceBoundary.textMatch:
        await visuals.waitForHighlightTargetToPaint(session.executor, step);
        return visuals.captureStepArtifacts(
          executor: session.executor,
          step: step,
          stepIndex: stepIndex,
          options: StepScreenshotOptions.waitForTextMatched(),
        );
      case StepEvidenceBoundary.orderedOperation:
        return visuals.captureStepArtifacts(
          executor: session.executor,
          step: step,
          stepIndex: stepIndex,
          options: StepScreenshotOptions.beforeAction(
            targetAlreadyResolved: true,
          ),
        );
      case StepEvidenceBoundary.navigation:
      case StepEvidenceBoundary.none:
        return false;
    }
  }

  final evidence = StepEvidenceSubscriber(
    capture: captureCompleted,
    captureBeforeMutation: captureBoundary,
  );
  final stepContext = StepContextSubscriber(
    onStepStarted: (index) => context.runtime.currentStepIndex = index,
  );
  final runtime = FlutterTestRuntime(session);
  final result = await ExecutionKernelRunner(
    plan: CompiledPlanCompiler().compile(testCase),
    runtime: runtime,
    eventSubscribers: [
      stepContext.call,
      (event) {
        events.add(
          '${event.kind.name}:${event.stepIndex}:${event.detail ?? ''}',
        );
        return evidence(event);
      },
    ],
  ).run();
  expect(result.outcome, AttemptOutcome.passed,
      reason: '${result.cause}; events=$events');
  expect(secondaryFailures, isEmpty);

  final captures = <_Capture>[];
  for (final frame in context.runtime.screenshotSheetFrames) {
    final observer = context.runtime.stepObservers.singleWhere(
      (artifact) => artifact.stepIndex == frame.stepIndex,
    );
    final imageData = await tester.runAsync(
      () => frame.image.toByteData(format: ui.ImageByteFormat.rawRgba),
    );
    captures.add(_Capture(
      stepIndex: frame.stepIndex,
      label: frame.label,
      observationJson: jsonEncode(observer.observationJson),
      rgba: imageData!.buffer.asUint8List(),
    ));
    frame.image.dispose();
  }
  await runtime.close();
  return _AdapterResult(events: events, captures: captures);
}

enum _EvidenceAdapter { hosted, standalone }

class _AdapterResult {
  const _AdapterResult({required this.events, required this.captures});

  final List<String> events;
  final List<_Capture> captures;
}

class _Capture {
  const _Capture({
    required this.stepIndex,
    required this.label,
    required this.observationJson,
    required this.rgba,
  });

  final int stepIndex;
  final String label;
  final String observationJson;
  final Uint8List rgba;
}

class _OperationFixture extends StatefulWidget {
  const _OperationFixture({super.key});

  @override
  State<_OperationFixture> createState() => _OperationFixtureState();
}

class _OperationFixtureState extends State<_OperationFixture> {
  var _after = false;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Text(_after ? 'After' : 'Before'),
              GestureDetector(
                key: const ValueKey('continue_action'),
                onTap: () => setState(() => _after = true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
}
