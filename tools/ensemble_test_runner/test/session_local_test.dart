import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/leaf_command_queue.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('attached session builds one executor with supplied config',
      (tester) async {
    const testCase = EnsembleTestCase(id: 'attached-session', steps: []);
    final context = EnsembleTestContext.fromTestCase(testCase);
    final config =
        EnsembleConfig(definitionProvider: _UnusedDefinitionProvider());
    final harness = _ConfigForwardingHarness(config);
    final session = LocalTestExecutionSession.attach(
      tester: tester,
      context: context,
      harness: harness,
      config: config,
      sessionId: testCase.id,
    );

    expect(session.executor.context, same(context));
    expect(session.executor.harness, same(harness));
    expect(session.executor.services, same(session.services));
    expect(session.executor.assertions, same(session.assertions));
    await session.executor.openScreenByName('Next');
    expect(harness.existingConfig, same(config));
    await session.close();
  });

  group('LeafCommandQueue', () {
    test('serializes concurrent leaf commands', () async {
      final queue = LeafCommandQueue();
      final order = <int>[];
      final first = queue.run(() async {
        order.add(1);
        await Future<void>.delayed(const Duration(milliseconds: 30));
        order.add(2);
        return 1;
      });
      final second = queue.run(() async {
        order.add(3);
        return 2;
      });
      expect(await Future.wait([first, second]), [1, 2]);
      expect(order, [1, 2, 3]);
    });

    test('rejects work after close', () async {
      final queue = LeafCommandQueue();
      queue.close();
      expect(
        () => queue.run(() async => 1),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('observable fingerprint', () {
    test('changes when text changes with same testId set', () {
      const screen = ScreenObservation(name: 'Login');
      final a = fingerprintForObservation(
        screen: screen,
        elements: const [
          UiElement(
            elementId: 'el_1',
            testId: 'title',
            text: 'Hello',
            state: UiElementState(visible: true, enabled: true),
          ),
        ],
      );
      final b = fingerprintForObservation(
        screen: screen,
        elements: const [
          UiElement(
            elementId: 'el_1',
            testId: 'title',
            text: 'Hello world',
            state: UiElementState(visible: true, enabled: true),
          ),
        ],
      );
      expect(a, isNot(equals(b)));
    });

    test('changes when enabled flips with same ids/count', () {
      const screen = ScreenObservation(name: 'Login');
      final a = fingerprintForObservation(
        screen: screen,
        elements: const [
          UiElement(
            elementId: 'el_1',
            testId: 'submit',
            state: UiElementState(visible: true, enabled: true),
          ),
        ],
      );
      final b = fingerprintForObservation(
        screen: screen,
        elements: const [
          UiElement(
            elementId: 'el_1',
            testId: 'submit',
            state: UiElementState(visible: true, enabled: false),
          ),
        ],
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('ObservationRegistry', () {
    test('classifies a missing handle in a retained observation as stale', () {
      final registry = ObservationRegistry();
      registry.registerObservation(
        observationId: 'obs_1',
        handles: const {},
      );

      expect(
        () => registry.resolve(
          observationId: 'obs_1',
          elementId: 'el_missing',
        ),
        throwsA(
          isA<TestExecutionError>()
              .having(
                (error) => error.code,
                'code',
                TestExecutionErrorCode.staleObservation,
              )
              .having(
                (error) => error.details['reason'],
                'reason',
                'elementNotRetained',
              ),
        ),
      );
    });

    testWidgets('rejects detached and expired observations', (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('x', key: ValueKey('title')),
        ),
      );
      final element = find.byKey(const ValueKey('title')).evaluate().single;
      final registry = ObservationRegistry(maxObservations: 3);
      final handle = SnapshotElementHandle(
        observationId: 'obs_0',
        elementId: 'el_1',
        testId: 'title',
        element: element,
        observableFingerprint: 'fp',
      );
      registry.registerObservation(
        observationId: 'obs_0',
        handles: {'el_1': handle},
      );
      expect(registry.containsObservation('obs_0'), isTrue);

      for (var i = 1; i <= 3; i++) {
        registry.registerObservation(
          observationId: 'obs_$i',
          handles: {
            'el_1': SnapshotElementHandle(
              observationId: 'obs_$i',
              elementId: 'el_1',
              testId: 'title',
              element: element,
              observableFingerprint: 'fp',
            ),
          },
        );
      }
      expect(registry.containsObservation('obs_0'), isFalse);

      expect(
        () => registry.resolve(observationId: 'obs_0', elementId: 'el_1'),
        throwsA(
          isA<TestExecutionError>().having(
            (e) => e.code,
            'code',
            TestExecutionErrorCode.staleObservation,
          ),
        ),
      );
    });

    testWidgets('revalidate fails for detached element without fallback',
        (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Text('x', key: ValueKey('title')),
        ),
      );
      final element = find.byKey(const ValueKey('title')).evaluate().single;
      final registry = ObservationRegistry();
      registry.registerObservation(
        observationId: 'obs_0',
        handles: {
          'el_1': SnapshotElementHandle(
            observationId: 'obs_0',
            elementId: 'el_1',
            testId: 'title',
            element: element,
            observableFingerprint: 'fp',
          ),
        },
      );

      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        () => registry.revalidate(observationId: 'obs_0', elementId: 'el_1'),
        throwsA(
          isA<TestExecutionError>().having(
            (e) => e.code,
            'code',
            TestExecutionErrorCode.staleObservation,
          ),
        ),
      );
    });
  });

  group('mapExecutorFailure', () {
    test('tap wait-for-id timeout is elementNotFound', () {
      final mapped = LocalTestExecutionSession.mapExecutorFailure(
        EnsembleTestFailure(
          'Timed out after 5000ms waiting for id "does_not_exist".',
        ),
      );
      expect(mapped.code, TestExecutionErrorCode.elementNotFound);
    });

    test('not hit-testable timeout is elementNotInteractable', () {
      final mapped = LocalTestExecutionSession.mapExecutorFailure(
        EnsembleTestFailure(
          'Timed out after 5000ms waiting for id "hidden_btn" to become '
          'hit-testable. It may be off-screen, disabled, or covered.',
        ),
      );
      expect(mapped.code, TestExecutionErrorCode.elementNotInteractable);
    });

    test('waitForApi timeout stays actionTimeout', () {
      final mapped = LocalTestExecutionSession.mapExecutorFailure(
        EnsembleTestFailure(
          'Timed out after 6000ms waiting for API "login" to be called.',
        ),
      );
      expect(mapped.code, TestExecutionErrorCode.actionTimeout);
    });
  });
}

final class _ConfigForwardingHarness extends EnsembleTestHarness {
  _ConfigForwardingHarness(this.config) : super(appPath: '', appHome: '');

  final EnsembleConfig config;
  EnsembleConfig? existingConfig;

  @override
  Future<EnsembleConfig> loadScreen({
    required WidgetTester tester,
    required EnsembleTestCase testCase,
    EnsembleConfig? existingConfig,
    EnsembleTestContext? context,
    EnsembleTestConfig suiteConfig = const EnsembleTestConfig(),
    Future<void> Function()? beforeBootstrap,
    Locale? forcedLocale,
  }) async {
    this.existingConfig = existingConfig;
    return config;
  }
}

final class _UnusedDefinitionProvider implements DefinitionProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
// ignore_for_file: deprecated_member_use_from_same_package
