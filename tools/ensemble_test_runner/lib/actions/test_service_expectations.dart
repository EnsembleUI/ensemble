import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:ensemble_test_runner/assertions/assertion_engine.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/actions/test_environment_operations.dart';
import 'package:ensemble_test_runner/src/core/operation_input.dart';

/// Resolves state assertions through application capabilities or the
/// standalone Ensemble harness.
///
/// Keeping this capability bridge separate from widget interaction makes the
/// step executor responsible for dispatching steps while this class owns the
/// service-versus-harness fallback rules.
class TestServiceExpectations {
  final ApplicationTestServices services;
  final AssertionEngine assertions;
  final EnsembleTestContext context;
  final bool hasHarness;

  const TestServiceExpectations({
    required this.services,
    required this.assertions,
    required this.context,
    required this.hasHarness,
  });

  void expectApiCalled(String name, int times) {
    final api = services.api;
    if (api != null) {
      final actual = api.callCount(name);
      if (actual != times) {
        throw EnsembleTestFailure(
          'Expected API "$name" to be called $times times, got $actual.',
        );
      }
      return;
    }
    _requireHarness('api');
    if (times == 0) {
      assertions.expectApiNotCalled(name);
    } else {
      assertions.expectApiCalled(name, times);
    }
  }

  void expectApiCallOrder(List<String> names) =>
      assertions.expectApiCallOrder(names);

  void expectLastApiCall(String name) => assertions.expectLastApiCall(name);

  void resetApiCalls() => resetTestApiCalls(
        services: services,
        context: context,
        hasHarness: hasHarness,
      );

  void expectStorage(String key, Object? expected) {
    final storage = services.storage;
    if (storage != null) {
      final actual = storage.read(key);
      if (actual != expected) {
        throw EnsembleTestFailure(
          'Expected storage "$key" to equal "$expected", got "$actual".',
        );
      }
      return;
    }
    _requireHarness('storage');
    assertions.expectStorage(key, expected);
  }

  Future<void> setStorage(OperationInput operation) async {
    await TestStorageOperations.write(
      services: services,
      context: context,
      hasHarness: hasHarness,
      operation: operation,
    );
  }

  Future<void> removeStorage(OperationInput operation) async {
    await TestStorageOperations.remove(
      services: services,
      context: context,
      hasHarness: hasHarness,
      operation: operation,
    );
  }

  Future<void> clearStorage() async {
    await TestStorageOperations.clear(
      services: services,
      context: context,
      hasHarness: hasHarness,
    );
  }

  void expectNavigateTo(String screen) {
    final navigation = services.navigation;
    if (navigation != null) {
      if (navigation.currentRoute != screen) {
        throw EnsembleTestFailure(
          'Expected route "$screen", got "${navigation.currentRoute}".',
        );
      }
      return;
    }
    _requireHarness('navigation');
    assertions.expectNavigateTo(screen);
  }

  void expectVisited(String screen) {
    final navigation = services.navigation;
    if (navigation != null) {
      if (!navigation.routeHistory.contains(screen)) {
        throw EnsembleTestFailure(
          'Expected screen "$screen" in navigation history, but visited '
          '${navigation.routeHistory}',
        );
      }
      return;
    }
    _requireHarness('navigation');
    assertions.expectVisited(screen);
  }

  void _requireHarness(String capability) {
    if (!hasHarness) {
      throw UnsupportedApplicationCapability(capability);
    }
  }
}
