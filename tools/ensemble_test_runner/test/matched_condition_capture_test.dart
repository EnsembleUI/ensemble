import 'package:ensemble_test_runner/entry/application_test_entry_support.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/step_report_capture.dart';
import 'package:flutter/rendering.dart';
import 'package:ensemble_test_runner/runner/test_visual_artifacts.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('host waitForText waits for highlight target paint readiness',
      (tester) async {
    final key = GlobalKey<_FadingTextAppState>();
    await tester.pumpWidget(_FadingTextApp(key: key));
    await tester.pumpAndSettle();
    key.currentState!.showText();
    await tester.pump(const Duration(milliseconds: 32));

    final context = _context('host-fading-text');
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      sessionId: 'host-fading-text',
    );
    final step = const TestStep(type: 'waitForText', args: {'text': 'Ready'});
    expect(_textOpacity(tester), lessThan(0.85));

    await captureHostStepReportArtifactsSafely(
      tester: tester,
      context: context,
      session: session,
      step: step,
      stepIndex: 0,
      secondaryFailures: [],
      atCurrentFrame: true,
    );

    expect(_textOpacity(tester), greaterThanOrEqualTo(0.85));
    expect(context.runtime.stepObservers, hasLength(1));
    expect(
      context.runtime.stepObservers.single.observationJson.toString(),
      contains('Ready'),
    );
    await session.close();
    _disposeFrames(context);
  });

  testWidgets('host and standalone freeze matched conditions on the same frame',
      (tester) async {
    final hostContext = _context('host-condition-frame');
    final hostKey = GlobalKey<_TransientConditionAppState>();
    await tester.pumpWidget(_TransientConditionApp(key: hostKey));
    hostKey.currentState!.replaceAfterNextFrame();
    final hostSession = LocalTestExecutionSession.attach(
      tester: tester,
      context: hostContext,
      sessionId: 'host-condition-frame',
    );
    await captureHostStepReportArtifactsSafely(
      tester: tester,
      context: hostContext,
      session: hostSession,
      step: const TestStep(type: 'expectText', args: {'text': 'Ready'}),
      stepIndex: 0,
      secondaryFailures: [],
      atCurrentFrame: true,
    );
    _expectMatchedFrame(hostContext);
    await tester.pump();
    await tester.pump();
    expect(find.text('Later'), findsOneWidget);
    await hostSession.close();
    _disposeFrames(hostContext);

    final standaloneKey = GlobalKey<_TransientConditionAppState>();
    await tester.pumpWidget(_TransientConditionApp(key: standaloneKey));
    standaloneKey.currentState!.replaceAfterNextFrame();
    final standaloneContext = _context('standalone-condition-frame');
    final standaloneSession = LocalTestExecutionSession.attach(
      tester: tester,
      context: standaloneContext,
      sessionId: 'standalone-condition-frame',
    );
    final visuals = TestVisualArtifacts(
      screenshotSheets: () => null,
      drainFlutterExceptions: (_) {},
    );

    await visuals.captureStepArtifacts(
      executor: standaloneSession.executor,
      step: const TestStep(type: 'expectText', args: {'text': 'Ready'}),
      stepIndex: 0,
      options: StepScreenshotOptions.matchedCondition(),
    );

    _expectMatchedFrame(standaloneContext);
    await tester.pump();
    await tester.pump();
    expect(find.text('Later'), findsOneWidget);
    await standaloneSession.close();
    _disposeFrames(standaloneContext);
  });
}

double _textOpacity(WidgetTester tester) {
  final element = find.text('Ready').evaluate().single;
  var opacity = 1.0;
  element.visitAncestorElements((ancestor) {
    final renderObject = ancestor.renderObject;
    if (renderObject is RenderOpacity) opacity *= renderObject.opacity;
    return true;
  });
  return opacity;
}

EnsembleTestContext _context(String id) => EnsembleTestContext.fromTestCase(
      EnsembleTestCase(id: id, steps: const []),
      config: const EnsembleTestConfig(
        screenshots: ScreenshotConfig(enabled: true),
      ),
    );

void _expectMatchedFrame(EnsembleTestContext context) {
  expect(context.runtime.stepObservers, hasLength(1));
  expect(
    context.runtime.stepObservers.single.observationJson.toString(),
    contains('Ready'),
  );
  expect(
    context.runtime.stepObservers.single.observationJson.toString(),
    isNot(contains('Later')),
  );
}

void _disposeFrames(EnsembleTestContext context) {
  for (final frame in context.runtime.screenshotSheetFrames) {
    frame.image.dispose();
  }
}

class _TransientConditionApp extends StatefulWidget {
  const _TransientConditionApp({super.key});

  @override
  State<_TransientConditionApp> createState() => _TransientConditionAppState();
}

class _TransientConditionAppState extends State<_TransientConditionApp> {
  var _label = 'Ready';

  void replaceAfterNextFrame() {
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _label = 'Later');
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(body: Text(_label)),
      );
}

class _FadingTextApp extends StatefulWidget {
  const _FadingTextApp({super.key});

  @override
  State<_FadingTextApp> createState() => _FadingTextAppState();
}

class _FadingTextAppState extends State<_FadingTextApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _opacity = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  void showText() => _opacity.forward();

  @override
  void dispose() {
    _opacity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: AnimatedBuilder(
            animation: _opacity,
            builder: (context, child) => Opacity(
              opacity: 0.2 + 0.8 * _opacity.value,
              child: child,
            ),
            child: const Text('Ready'),
          ),
        ),
      );
}
