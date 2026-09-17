import 'package:ensemble_test_runner/actions/test_execution_config.dart';
import 'package:ensemble_test_runner/actions/test_step_executor.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/test_execution_session.dart';
import 'package:ensemble_test_runner/session/test_session_factory.dart';
import 'package:flutter_test/flutter_test.dart';

/// Standalone (YAML-independent) session factory for Flutter test contexts.
///
/// Requires a valid [WidgetTester] / test binding. Reuses
/// [EnsembleTestHarness] — does not invent a second bootstrap path.
/// Creates one shared [AssertionEngine] + [TestStepExecutor] per session.
class StandaloneTestSessionFactory implements TestSessionFactory {
  StandaloneTestSessionFactory({
    required this.tester,
    required this.harness,
    this.suiteConfig = const EnsembleTestConfig(),
    TestExecutionConfig? executionConfig,
  }) : executionConfig = executionConfig ?? const TestExecutionConfig();

  final WidgetTester tester;
  final EnsembleTestHarness harness;
  final EnsembleTestConfig suiteConfig;
  final TestExecutionConfig executionConfig;

  @override
  Future<TestExecutionSession> create(TestSessionConfiguration config) async {
    final startScreen = config.startScreen;
    if (startScreen == null || startScreen.isEmpty) {
      throw ArgumentError(
        'TestSessionConfiguration.startScreen is required for standalone create',
      );
    }

    final testCase = EnsembleTestCase(
      id: config.sessionId ?? 'standalone',
      startScreen: startScreen,
      startScreenInputs: config.startScreenInputs,
      steps: const [],
    );
    final overlay = TestApiProviderOverlay(mocks: const {});
    final logger = TestLogger();
    final context = EnsembleTestContext(
      testCase: testCase,
      config: suiteConfig,
      apiOverlay: overlay,
      logger: logger,
      setup: const EnsembleTestSetup(),
    );

    await harness.loadScreen(
      tester: tester,
      testCase: testCase,
      context: context,
      suiteConfig: suiteConfig,
    );

    final assertions = AssertionEngine(tester: tester, context: context);
    final executor = TestStepExecutor(
      tester: tester,
      context: context,
      assertions: assertions,
      harness: harness,
      executionConfig: executionConfig,
    );

    return LocalTestExecutionSession.standalone(
      tester: tester,
      harness: harness,
      context: context,
      sessionId: config.sessionId,
      permissions: config.permissions,
      assertions: assertions,
      executor: executor,
    );
  }
}
