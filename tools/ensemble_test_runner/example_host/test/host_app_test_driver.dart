import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner_host_example/host_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the Flutter host. Widget mode mocks MethodChannels; integration
/// mode keeps the simulator/device plugins. [EnsembleHost] still mounts the
/// Ensemble shell after login; runtime init happens in [prepareTest] so API
/// mocks can attach before [launch].
class HostAppTestDriver implements ApplicationTestDriver {
  static bool get _isIntegration =>
      const String.fromEnvironment('ensembleTestExecutionMode') ==
      'integration';

  void _ensureRuntime() {
    if (_isIntegration) {
      EnsembleTestHarness.ensureIntegrationRuntime();
    } else {
      EnsembleTestHarness.ensureTestPlugins();
    }
  }

  @override
  Future<void> setUpSuite(TestSuiteContext context) async {
    _ensureRuntime();
  }

  @override
  Future<void> prepareTest(TestLaunchContext context) async {
    _ensureRuntime();
    EnsembleTestHarness.resetTestRuntime();
    // Initialize Ensemble before launch so applyInPlaceSetup can install the
    // API mock overlay onto the real config before the widget tree mounts.
    await Ensemble().initialize();
  }

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    _ensureRuntime();
    await tester.pumpWidget(const HostApp());
    await tester.pump();
    return const _Handle();
  }

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    EnsembleTestHarness.resetTestRuntime();
  }

  @override
  Future<void> tearDownSuite() async {}
}

class _Handle implements TestApplicationHandle {
  const _Handle();

  @override
  ApplicationTestServices get services => const ApplicationTestServices();
}
