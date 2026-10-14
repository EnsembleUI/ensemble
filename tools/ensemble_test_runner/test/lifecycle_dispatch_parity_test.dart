import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'support/test_step_executor_handler_harness.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/src/core/operation.dart';
import 'package:ensemble_test_runner/src/runtime/operation_registry.dart'
    show operationRegistry;
import 'package:ensemble_test_runner/src/runtime/flutter_test_runtime.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('authored and compiled lifecycle inputs share execution routes',
      (tester) async {
    const cases = <({String name, Map<String, dynamic> input})>[
      (name: 'openScreen', input: {'name': 'Next'}),
      (name: 'reloadScreen', input: {}),
      (name: 'restartApp', input: {}),
      (name: 'resetAppState', input: {}),
      (name: 'trigger', input: {'action': 'onLoad'}),
      (name: 'goBack', input: {}),
    ];

    for (final lifecycle in cases) {
      final authored = await _runLifecycle(
        tester,
        lifecycle.name,
        lifecycle.input,
        compiled: false,
      );
      final compiled = await _runLifecycle(
        tester,
        lifecycle.name,
        lifecycle.input,
        compiled: true,
      );

      expect(compiled.events, authored.events, reason: lifecycle.name);
      expect(compiled.openedScreens, authored.openedScreens,
          reason: lifecycle.name);
      expect(authored.events.where((event) => event.startsWith('evidence:')),
          hasLength(1),
          reason: lifecycle.name);
    }
  });
}

Future<({List<String> events, List<String> openedScreens})> _runLifecycle(
  WidgetTester tester,
  String name,
  Map<String, dynamic> input, {
  required bool compiled,
}) async {
  ScreenTracker().clearAll();
  await tester.pumpWidget(MaterialApp(
    home: const Scaffold(body: Text('First')),
  ));
  Future<void>? routeResult;
  if (name == 'goBack') {
    routeResult = Navigator.of(tester.element(find.text('First'))).push<void>(
      MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Second'))),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  final context = EnsembleTestContext(
    testCase: EnsembleTestCase(
      id: 'lifecycle-$name-${compiled ? 'compiled' : 'authored'}',
      startScreen: 'Home',
      steps: const [],
    ),
    apiOverlay: TestApiProviderOverlay(mocks: const {}),
    logger: TestLogger(),
    setup: const EnsembleTestSetup(),
  );
  final executor = _RecordingLifecycleExecutor(
    tester: tester,
    context: context,
    assertions: AssertionEngine(tester: tester, context: context),
  );
  final events = <String>[];
  executor.onEvidenceBoundary = (step) {
    events.add('evidence:${step.type}');
  };
  executor.onNamedOperationEvidenceBoundary = (operation) {
    events.add('evidence:$operation');
  };
  final session = LocalTestExecutionSession.attach(
    tester: tester,
    context: context,
    executor: executor,
    permissions: SessionPermissions.testController,
  );
  final runtime = FlutterTestRuntime(session);

  if (compiled) {
    final descriptor = operationRegistry.lookup(name)!;
    final result = await runtime.execute(TestOperation(
      id: 'compiled-$name',
      name: descriptor.name,
      kind: descriptor.kind,
      handlerKey: descriptor.handlerKey,
      input: input,
      source: SourceLocation('lifecycle-dispatch-parity', 'steps[0]'),
    ));
    expect(result.succeeded, isTrue, reason: '$name: ${result.error}');
  } else {
    await executor.execute(TestStep(type: name, args: input));
  }

  final result = (
    events: List<String>.of(events),
    openedScreens: List<String>.of(executor.openedScreens),
  );
  await runtime.close();
  if (routeResult != null) await routeResult;
  return result;
}

final class _RecordingLifecycleExecutor extends TestStepExecutor {
  _RecordingLifecycleExecutor({
    required super.tester,
    required super.context,
    required super.assertions,
  });

  final openedScreens = <String>[];

  @override
  Future<void> openScreenByName(
    String screen, {
    Future<void> Function()? beforeMutation,
  }) async {
    await beforeMutation?.call();
    openedScreens.add(screen);
  }
}
