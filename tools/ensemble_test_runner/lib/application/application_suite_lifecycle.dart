import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/src/core/async_cleanup_stack.dart';

/// Owns the suite boundary shared by standalone and host applications.
///
/// A driver is given one cleanup opportunity as soon as setup begins. This is
/// deliberately stricter than "setup completed": a driver can allocate a
/// resource before its setup future fails. Attempt execution, test services,
/// and application teardown share the caller's cleanup stack so dependencies
/// close in reverse registration order across adapter boundaries.
final class ApplicationSuiteLifecycle {
  const ApplicationSuiteLifecycle();

  Future<T> run<T>({
    required ApplicationTestDriver application,
    required TestSuiteContext context,
    required AsyncCleanupStack cleanup,
    required Future<T> Function() execute,
  }) {
    // Register before setup: a driver may allocate resources before setup
    // reports an error, and must receive exactly one teardown opportunity.
    // The caller owns the suite stack so resources registered while executing
    // are released before the driver they depend on.
    cleanup.add(application.tearDownSuite);
    return () async {
      await application.setUpSuite(context);
      return execute();
    }();
  }
}
