import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Lifecycle adapter that preserves the existing standalone Ensemble harness.
///
/// The legacy [EnsembleTestRunner] remains the compatibility execution path;
/// this adapter lets lifecycle-aware integrations use the same harness without
/// introducing a second Ensemble bootstrap implementation.
class StandaloneEnsembleTestDriver
    implements ScreenLaunchApplicationTestDriver {
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
    final config = await harness.loadScreen(
      tester: tester,
      testCase: context.testCase,
      context: ensembleContext,
      suiteConfig: context.config,
    );
    YamlTestSession.navigationFlow.beginTest(
      ScreenTracker().getCurrentScreenIdentifier(),
    );
    return StandaloneEnsembleApplicationHandle(
      context: ensembleContext,
      configDescription: {
        'launchKind': TestApplicationLaunchKind.standaloneEnsemble.name,
        'startScreen': context.testCase.startScreen,
        'configType': config.runtimeType.toString(),
      },
    );
  }

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {
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
  }) : services = ApplicationTestServices(
          navigation: const _EnsembleNavigationService(),
          api: _EnsembleApiService(context),
          storage: const _EnsembleStorageService(),
          metadata: _EnsembleMetadataService(configDescription),
        );

  final EnsembleTestContext context;

  @override
  final ApplicationTestServices services;
}

class _EnsembleNavigationService implements NavigationTestService {
  const _EnsembleNavigationService();

  @override
  String? get currentRoute => ScreenTracker().getCurrentScreenIdentifier();

  @override
  List<String> get routeHistory =>
      List<String>.unmodifiable(YamlTestSession.navigationFlow.flow);
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
