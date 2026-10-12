import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/local/standalone_test_session_factory.dart';
import 'package:ensemble_test_runner/session/test_session_factory.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('standalone session owns navigation recording through close',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    ScreenTracker().clearAll();
    final harness = _Harness();
    final factory = StandaloneTestSessionFactory(
      tester: tester,
      harness: harness,
    );

    final session = await factory.create(
      TestSessionConfiguration(
          sessionId: 'navigation-session', startScreen: 'Home'),
    ) as LocalTestExecutionSession;

    expect(session.context.navigationFlow.isListening, isTrue);
    expect(session.services.navigation?.routeHistory, ['Ready']);
    await session.close();
    expect(session.context.navigationFlow.isListening, isFalse);
    ScreenTracker().clearAll();
  });

  testWidgets('failed standalone bootstrap releases its navigation listener',
      (tester) async {
    EnsembleTestHarness.ensureTestPlugins();
    ScreenTracker().clearAll();
    final harness = _Harness(failLoad: true);
    final factory = StandaloneTestSessionFactory(
      tester: tester,
      harness: harness,
    );

    await expectLater(
      factory.create(TestSessionConfiguration(startScreen: 'Home')),
      throwsA(isA<StateError>().having(
        (error) => error.message,
        'message',
        'bootstrap failed',
      )),
    );

    expect(harness.loadedContext, isNotNull);
    expect(harness.loadedContext!.navigationFlow.isListening, isFalse);
    ScreenTracker().clearAll();
  });
}

class _Harness extends EnsembleTestHarness {
  _Harness({this.failLoad = false}) : super(appPath: '', appHome: '');

  final bool failLoad;
  EnsembleTestContext? loadedContext;

  @override
  Future<EnsembleConfig> loadScreen({
    required WidgetTester tester,
    required EnsembleTestCase testCase,
    EnsembleConfig? existingConfig,
    EnsembleTestContext? context,
    EnsembleTestConfig suiteConfig = const EnsembleTestConfig(),
    Future<void> Function()? beforeBootstrap,
    Locale? forcedLocale,
  }) async {
    loadedContext = context;
    await beforeBootstrap?.call();
    ScreenTracker().trackScreen(screenName: 'Ready');
    await tester.pump();
    if (failLoad) throw StateError('bootstrap failed');
    return EnsembleConfig(definitionProvider: _UnusedDefinitionProvider());
  }
}

class _UnusedDefinitionProvider implements DefinitionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
