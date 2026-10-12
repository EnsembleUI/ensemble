import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/test_session.dart';
import 'package:ensemble_test_runner/runner/attempt_lifecycle_coordinator.dart';
import 'package:ensemble_test_runner/src/core/cleanup_after_failure.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lifecycle adapter that boots a standalone Ensemble application through the
/// shared attempt lifecycle and runtime contracts.
class StandaloneEnsembleTestDriver
    implements
        ScreenLaunchApplicationTestDriver,
        AttemptStateApplicationTestDriver<EnsembleTestContext> {
  StandaloneEnsembleTestDriver({required this.harness});

  final EnsembleTestHarness harness;

  @override
  Future<void> setUpSuite(TestSuiteContext context) =>
      EnsembleTestHarness.ensurePreSuiteStorageSnapshot();

  @override
  Future<void> prepareTest(TestLaunchContext context) =>
      EnsembleTestHarness.restorePreSuiteStorage();

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    final ensembleContext = EnsembleTestContext.fromTestCase(
      context.testCase,
      config: context.config,
    );
    return runWithCleanupPreservingPrimary<TestApplicationHandle>(
      body: () async {
        // Listener startup can fail while a previous cancellation is still
        // settling. Keep it inside this ownership guard so partially completed
        // startup reaches the same teardown path as harness bootstrap failure.
        await ensembleContext.navigationFlow.startListeningWhenReady();
        return await AttemptLifecycleCoordinator.launchAndBeginTest(
          navigationFlow: ensembleContext.navigationFlow,
          launch: () => _launch(
            tester,
            context,
            ensembleContext,
            ownsNavigationFlow: true,
          ),
        );
      },
      cleanup: ensembleContext.navigationFlow.stopListening,
      onCleanupFailure: (error, stackTrace) {
        ensembleContext.logger.log(
          'navigationCleanupError: $error\n$stackTrace',
        );
      },
    );
  }

  @override
  Future<TestApplicationHandle> launchWithAttemptState(
    WidgetTester tester,
    TestLaunchContext context,
    EnsembleTestContext ensembleContext,
  ) =>
      // AttemptLifecycleCoordinator owns listener startup, launch-event flush,
      // and test-route boundary for this path. Keeping those operations here
      // duplicated the shared lifecycle and made it possible for the two
      // owners to disagree about when route history starts.
      _launch(tester, context, ensembleContext, ownsNavigationFlow: false);

  Future<TestApplicationHandle> _launch(
    WidgetTester tester,
    TestLaunchContext context,
    EnsembleTestContext ensembleContext, {
    required bool ownsNavigationFlow,
  }) async {
    final config = await harness.loadScreen(
      tester: tester,
      testCase: context.testCase,
      context: ensembleContext,
      suiteConfig: context.config,
    );
    return StandaloneEnsembleApplicationHandle(
      context: ensembleContext,
      configDescription: {
        'launchKind': TestApplicationLaunchKind.standaloneEnsemble.name,
        'startScreen': context.testCase.startScreen,
        'configType': config.runtimeType.toString(),
      },
      ownsNavigationFlow: ownsNavigationFlow,
    );
  }

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {
    if (handle is StandaloneEnsembleApplicationHandle &&
        handle.ownsNavigationFlow) {
      await handle.context.navigationFlow.stopListening();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await EnsembleTestHarness.restorePreSuiteStorage();
  }

  @override
  Future<void> tearDownSuite() =>
      EnsembleTestHarness.restorePreSuiteStorageAtSuiteEnd();
}

class StandaloneEnsembleApplicationHandle implements TestApplicationHandle {
  StandaloneEnsembleApplicationHandle({
    required this.context,
    required Map<String, Object?> configDescription,
    required this.ownsNavigationFlow,
  }) : services = ApplicationTestServices(
          navigation: _EnsembleNavigationService(context.navigationFlow),
          api: _EnsembleApiService(context),
          storage: const _EnsembleStorageService(),
          metadata: _EnsembleMetadataService(configDescription),
        );

  final EnsembleTestContext context;
  final bool ownsNavigationFlow;

  @override
  final ApplicationTestServices services;
}

class _EnsembleNavigationService implements NavigationTestService {
  const _EnsembleNavigationService(this._navigationFlow);

  final NavigationFlowRecorder _navigationFlow;

  @override
  String? get currentRoute => ScreenTracker().getCurrentScreenIdentifier();

  @override
  List<String> get routeHistory =>
      List<String>.unmodifiable(_navigationFlow.flow);
}

class _EnsembleApiService implements ApiMockingTestService {
  _EnsembleApiService(this.context);

  final EnsembleTestContext context;

  @override
  int callCount(String name) => context.apiOverlay.callCount(name);

  @override
  void applyMocks(TestMocks mocks) {
    for (final entry in mocks.apis.entries) {
      context.apiOverlay.setMock(entry.key, entry.value);
    }
  }

  @override
  void resetCalls() => context.apiOverlay.resetCalls();
}

class _EnsembleStorageService implements StorageTestService {
  const _EnsembleStorageService();

  @override
  Future<void> apply(Map<String, dynamic> state) async {
    final storage = StorageManager();
    for (final entry in state.entries) {
      storage.write(entry.key, entry.value);
    }
  }

  @override
  Future<void> restore() => EnsembleTestHarness.restorePreSuiteStorage();

  @override
  Object? read(String key) => StorageManager().read(key);

  @override
  Future<void> write(String key, Object? value) async {
    StorageManager().write(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await StorageManager().remove(key);
  }

  @override
  Future<void> clear() => StorageManager().clearPublicStorage();
}

class _EnsembleMetadataService implements RuntimeMetadataService {
  _EnsembleMetadataService(this.metadata);

  final Map<String, Object?> metadata;

  @override
  Map<String, Object?> describe() => Map.unmodifiable(metadata);
}
