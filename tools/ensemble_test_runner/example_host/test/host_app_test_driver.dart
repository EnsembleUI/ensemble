import 'package:ensemble/ensemble.dart';
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner_host_example/host_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the Flutter host. Ensemble plugins are mocked here; [EnsembleHost]
/// still initializes (or reuses) the runtime after login.
class HostAppTestDriver implements ApplicationTestDriver {
  @override
  Future<void> setUpSuite(TestSuiteContext context) async {
    EnsembleTestHarness.ensureTestPlugins();
  }

  @override
  Future<void> prepareTest(TestLaunchContext context) async {
    EnsembleTestHarness.ensureTestPlugins();
    EnsembleTestHarness.resetTestRuntime();
  }

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) async {
    EnsembleTestHarness.ensureTestPlugins();
    await tester.runAsync(Ensemble().initialize);
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
