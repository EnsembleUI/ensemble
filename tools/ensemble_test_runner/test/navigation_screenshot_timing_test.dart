import 'dart:async';

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'unpainted navigation target is not published as screenshot evidence',
    (tester) async {
      ScreenTracker().clearAll();
      var screen = 'Loading';
      late StateSetter updateScreen;
      await tester.pumpWidget(MaterialApp(
        home: StatefulBuilder(builder: (context, setState) {
          updateScreen = setState;
          return Scaffold(body: Text('$screen screen'));
        }),
      ));

      const step = TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'Transient'},
      );
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'navigation-frame-timing', steps: [step]),
        config: const EnsembleTestConfig(
          screenshots: ScreenshotConfig(enabled: true),
        ),
      );
      final session = LocalTestExecutionSession.attach(
        tester: tester,
        context: context,
      );
      addTearDown(session.close);
      final visuals = TestVisualArtifacts(
        screenshotSheets: () => null,
        drainFlutterExceptions: (_) {},
      );

      // The tracker announces the destination before its frame has painted.
      // The route is replaced during the first paint opportunity.
      ScreenTracker().trackScreen(screenName: 'Transient');
      Timer(const Duration(milliseconds: 1), () {
        updateScreen(() => screen = 'Final');
        ScreenTracker().trackScreen(screenName: 'Final');
      });

      final matchedCapture = await visuals.captureWaitForNavigationScreenshot(
        executor: session.executor,
        step: step,
        stepIndex: 0,
      );

      expect(matchedCapture, isFalse);
      expect(context.runtime.screenshotSheetFrames, isEmpty);
      expect(find.text('Final screen'), findsOneWidget);

      // The ordinary step-completion fallback records the screen actually
      // rendered after the transient destination disappeared.
      final fallbackCaptured = await visuals.captureStepArtifacts(
        executor: session.executor,
        step: step,
        stepIndex: 0,
        options: StepScreenshotOptions.afterCondition(step),
      );
      expect(fallbackCaptured, isTrue);
      expect(context.runtime.screenshotSheetFrames, hasLength(1));
      expect(
        context.runtime.stepObservers.single.observationJson.toString(),
        contains('Final'),
      );
      expect(
        context.runtime.stepObservers.single.observationJson.toString(),
        isNot(contains('Transient')),
      );
      ScreenTracker().clearAll();
    },
  );

  testWidgets(
    'secure content is included in navigation and completed-step captures',
    (tester) async {
      ScreenTracker().clearAll();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TextField(
            obscureText: true,
            controller: TextEditingController(text: 'private value'),
          ),
        ),
      ));

      const step = TestStep(
        type: 'waitForNavigation',
        args: {'screen': 'SecureDestination'},
      );
      final context = EnsembleTestContext.fromTestCase(
        const EnsembleTestCase(id: 'secure-navigation-capture', steps: [step]),
        config: const EnsembleTestConfig(
          screenshots: ScreenshotConfig(
            enabled: true,
          ),
        ),
      );
      final session = LocalTestExecutionSession.attach(
        tester: tester,
        context: context,
      );
      addTearDown(session.close);
      final visuals = TestVisualArtifacts(
        screenshotSheets: () => null,
        drainFlutterExceptions: (_) {},
      );

      ScreenTracker().trackScreen(screenName: 'SecureDestination');
      final captureStartedAt = tester.binding.clock.now();
      final navigationCaptured =
          await visuals.captureWaitForNavigationScreenshot(
        executor: session.executor,
        step: step,
        stepIndex: 0,
      );
      expect(
        tester.binding.clock.now().difference(captureStartedAt),
        const Duration(milliseconds: 50),
        reason: 'an already-painted destination needs only its first frame',
      );
      final completionCaptured = await visuals.captureStepArtifacts(
        executor: session.executor,
        step: step,
        stepIndex: 0,
        options: StepScreenshotOptions.afterCondition(step),
      );

      expect(navigationCaptured, isTrue);
      expect(completionCaptured, isTrue);
      expect(context.runtime.screenshotSheetFrames, isNotEmpty);
      expect(context.runtime.stepObservers, isNotEmpty);
      ScreenTracker().clearAll();
    },
  );
}
