import 'package:ensemble_test_runner/application/application_test_types.dart';
import 'package:flutter_test/flutter_test.dart';

export 'package:ensemble_test_runner/application/application_test_types.dart';

/// Application-owned lifecycle used by pure Flutter and mixed applications.
abstract interface class ApplicationTestDriver {
  Future<void> setUpSuite(TestSuiteContext context);

  Future<void> prepareTest(TestLaunchContext context);

  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  );

  /// Called after every successfully prepared attempt, including launch
  /// failures. [handle] is null when launch did not complete.
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  );

  Future<void> tearDownSuite();
}

/// Opt-in marker for drivers that interpret YAML [EnsembleTestCase.startScreen].
abstract interface class ScreenLaunchApplicationTestDriver
    implements ApplicationTestDriver {}
