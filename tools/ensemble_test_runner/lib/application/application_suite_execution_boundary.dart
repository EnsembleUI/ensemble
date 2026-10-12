import 'dart:async';

import 'package:ensemble_test_runner/application/application_suite_lifecycle.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';
import 'package:ensemble_test_runner/runner/test_service_manager.dart';
import 'package:ensemble_test_runner/src/core/async_cleanup_stack.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owns the resources that belong to one application suite.
///
/// Both application-owned and standalone runs use this boundary. Registering
/// service cleanup before startup makes partial startup safe, while the
/// application lifecycle owns driver setup and teardown inside the same
/// primary-error-preserving cleanup stack.
final class ApplicationSuiteExecutionBoundary {
  const ApplicationSuiteExecutionBoundary();

  Future<T> run<T>({
    required WidgetTester tester,
    required TestServiceManager services,
    required ApplicationTestDriver driver,
    required TestSuiteContext context,
    required Future<T> Function(
      void Function(FutureOr<void> Function()) registerCleanup,
    ) execute,
  }) {
    final cleanup = AsyncCleanupStack();
    // An empty service set cannot own a process. Avoid registering and
    // invoking a no-op stop path for the common application suite, while
    // retaining the cleanup guard for configured services that may partially
    // start before setup fails.
    if (services.hasConfiguredServices) {
      cleanup.add(() => LiveAsyncCallSupport.run<void>(services.stopAll));
    }
    return cleanup.run(() async {
      if (services.hasConfiguredServices) {
        await tester.runAsync(services.startAll);
      }
      return const ApplicationSuiteLifecycle().run(
        application: driver,
        context: context,
        cleanup: cleanup,
        execute: () => execute(cleanup.add),
      );
    });
  }
}
