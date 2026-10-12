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

  /// Called after every attempt whose preparation started, including failures
  /// from preparation and launch. [handle] is null when launch did not
  /// complete.
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  );

  Future<void> tearDownSuite();
}

/// Optional capability for drivers that can launch from shared attempt state.
///
/// The runner passes the same state instance used by execution and reporting,
/// avoiding a second runtime context for an adapter that owns its bootstrap.
abstract interface class AttemptStateApplicationTestDriver<TState> {
  Future<TestApplicationHandle> launchWithAttemptState(
    WidgetTester tester,
    TestLaunchContext context,
    TState attemptState,
  );
}

/// Opt-in marker for drivers that interpret YAML [EnsembleTestCase.startScreen].
abstract interface class ScreenLaunchApplicationTestDriver
    implements ApplicationTestDriver {}
