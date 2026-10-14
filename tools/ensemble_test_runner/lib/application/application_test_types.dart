import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// How a YAML suite obtains the application under test.
enum TestApplicationLaunchKind { standaloneEnsemble, applicationProvided }

/// Suite-scoped information supplied to an [ApplicationTestDriver].
class TestSuiteContext {
  final String runId;
  final EnsembleTestConfig config;
  final TestApplicationLaunchKind launchKind;

  const TestSuiteContext({
    required this.runId,
    required this.config,
    required this.launchKind,
  });
}

/// Attempt-scoped information supplied to an [ApplicationTestDriver].
class TestLaunchContext {
  final String attemptId;
  final int attempt;
  final EnsembleTestCase testCase;
  final EnsembleTestConfig config;
  final Object? checkpoint;

  const TestLaunchContext({
    required this.attemptId,
    required this.attempt,
    required this.testCase,
    required this.config,
    this.checkpoint,
  });

  String get testId => testCase.id;
  Map<String, dynamic> get fixtures => testCase.inlineMocks;
  Map<String, dynamic> get initialState => testCase.initialState;
}

class UnsupportedApplicationCapability implements Exception {
  const UnsupportedApplicationCapability(this.capability);

  final String capability;

  @override
  String toString() => 'Application capability "$capability" is unavailable.';
}

class ApplicationTestCrash implements Exception {
  const ApplicationTestCrash(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Navigation state optionally exposed by an application.
abstract interface class NavigationTestService {
  String? get currentRoute;
  List<String> get routeHistory;
}

/// API observation/mocking optionally exposed by an application.
abstract interface class ApiTestService {
  int callCount(String name);
}

abstract interface class ApiMockingTestService implements ApiTestService {
  void applyMocks(TestMocks mocks);
  void resetCalls();
}

/// Storage fixture operations explicitly owned by an application.
abstract interface class StorageTestService {
  Future<void> apply(Map<String, dynamic> state);
  Future<void> restore();
  Object? read(String key);
  Future<void> write(String key, Object? value);
  Future<void> remove(String key);
  Future<void> clear();
}

/// Optional application/runtime metadata for observations and reports.
abstract interface class RuntimeMetadataService {
  Map<String, Object?> describe();
}

/// Typed capabilities exposed by the launched application.
class ApplicationTestServices {
  final NavigationTestService? navigation;
  final ApiTestService? api;
  final StorageTestService? storage;
  final RuntimeMetadataService? metadata;

  const ApplicationTestServices({
    this.navigation,
    this.api,
    this.storage,
    this.metadata,
  });
}

/// The launched application instance. This is not an execution session.
abstract interface class TestApplicationHandle {
  ApplicationTestServices get services;
}

/// Optional application-owned support for YAML `session:` dependencies.
abstract interface class ApplicationCheckpointDriver {
  String get checkpointCoverage;

  Future<Object> captureCheckpoint(
    TestLaunchContext context,
    TestApplicationHandle handle,
  );

  Future<void> restoreCheckpoint(
    TestLaunchContext context,
    Object checkpoint,
  );
}
