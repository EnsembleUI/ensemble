import 'package:ensemble_test_runner/application/application_suite_lifecycle.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/core/async_cleanup_stack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApplicationSuiteLifecycle', () {
    test('runs suite setup, body, and teardown in order', () async {
      final driver = _RecordingDriver();
      final value = await _runLifecycle(
        application: driver,
        context: _suiteContext(),
        execute: () async {
          driver.events.add('execute');
          return 42;
        },
      );

      expect(value, 42);
      expect(driver.events, ['setup', 'execute', 'teardown']);
    });

    test('tears down when setup allocates then throws', () async {
      final driver = _RecordingDriver(failSetup: true);

      await expectLater(
        _runLifecycle<void>(
          application: driver,
          context: _suiteContext(),
          execute: () async => fail('body must not run'),
        ),
        throwsStateError,
      );

      expect(driver.events, ['setup', 'teardown']);
    });

    test('tears down when execution fails', () async {
      final driver = _RecordingDriver();

      await expectLater(
        _runLifecycle<void>(
          application: driver,
          context: _suiteContext(),
          execute: () async {
            driver.events.add('execute');
            throw StateError('execution failed');
          },
        ),
        throwsStateError,
      );

      expect(driver.events, ['setup', 'execute', 'teardown']);
    });

    test('retains the execution failure when teardown also fails', () async {
      final driver = _RecordingDriver(failTeardown: true);

      await expectLater(
        _runLifecycle<void>(
          application: driver,
          context: _suiteContext(),
          execute: () async => throw StateError('execution failed'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'execution failed',
          ),
        ),
      );

      expect(driver.events, ['setup', 'teardown']);
    });

    test('retains the setup failure when teardown also fails', () async {
      final driver = _RecordingDriver(failSetup: true, failTeardown: true);

      await expectLater(
        _runLifecycle<void>(
          application: driver,
          context: _suiteContext(),
          execute: () async => fail('body must not run'),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'setup failed',
          ),
        ),
      );

      expect(driver.events, ['setup', 'teardown']);
    });

    test('execution cleanup runs before application teardown', () async {
      final driver = _RecordingDriver();
      final events = <String>[];
      final cleanup = AsyncCleanupStack();

      await cleanup.run(
        () => const ApplicationSuiteLifecycle().run<void>(
          application: driver,
          context: _suiteContext(),
          cleanup: cleanup,
          execute: () async {
            events.add('execute');
            // Model a resource created by suite execution that depends on the
            // application remaining alive until cleanup has completed.
            cleanup.add(() => events.add('resource cleanup'));
          },
        ),
      );

      expect(events, ['execute', 'resource cleanup']);
      expect(driver.events, ['setup', 'teardown']);
    });
  });
}

Future<T> _runLifecycle<T>({
  required ApplicationTestDriver application,
  required TestSuiteContext context,
  required Future<T> Function() execute,
}) async {
  final cleanup = AsyncCleanupStack();
  return cleanup.run(
    () => const ApplicationSuiteLifecycle().run(
      application: application,
      context: context,
      cleanup: cleanup,
      execute: execute,
    ),
  );
}

TestSuiteContext _suiteContext() => const TestSuiteContext(
      runId: 'suite',
      config: EnsembleTestConfig(),
      launchKind: TestApplicationLaunchKind.applicationProvided,
    );

final class _RecordingDriver implements ApplicationTestDriver {
  _RecordingDriver({this.failSetup = false, this.failTeardown = false});

  final bool failSetup;
  final bool failTeardown;
  final events = <String>[];

  @override
  Future<void> setUpSuite(TestSuiteContext context) async {
    events.add('setup');
    if (failSetup) throw StateError('setup failed');
  }

  @override
  Future<void> tearDownSuite() async {
    events.add('teardown');
    if (failTeardown) throw StateError('teardown failed');
  }

  @override
  Future<void> prepareTest(TestLaunchContext context) async {}

  @override
  Future<TestApplicationHandle> launch(
    WidgetTester tester,
    TestLaunchContext context,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> tearDownTest(
    WidgetTester tester,
    TestLaunchContext context,
    TestApplicationHandle? handle,
  ) async {}
}
