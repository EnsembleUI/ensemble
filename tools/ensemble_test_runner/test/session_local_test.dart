import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/leaf_command_queue.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/local/observation_registry.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:ensemble_test_runner/session/observation/ui_observation.dart';
import 'package:ensemble_test_runner/session/session_capabilities.dart';
import 'package:ensemble_test_runner/session/yaml/session_step_routing.dart';
import 'package:ensemble_test_runner/session/yaml/yaml_step_migration_matrix.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YamlStepMigrationMatrix', () {
    test('covers every registry entry and alias canonical', () {
      final missing = <String>[];
      for (final key in TestStepRegistry.entries.keys) {
        if (YamlStepMigrationMatrix.pathFor(key) == null) {
          missing.add(key);
        }
      }
      expect(missing, isEmpty, reason: 'Missing matrix paths: $missing');

      for (final key in TestStepRegistry.entries.keys) {
        final canonical = TestStepVocabulary.resolveStepType(key);
        expect(
          YamlStepMigrationMatrix.pathFor(canonical),
          isNotNull,
          reason: 'canonical $canonical for $key missing',
        );
      }
    });

    test('control-flow steps are classified as control', () {
      for (final step in ['group', 'repeat', 'optional', 'ifVisible']) {
        expect(YamlStepMigrationMatrix.isControlFlow(step), isTrue);
      }
    });

    test('session routing matches category-derived paths for all registry keys',
        () {
      for (final e in TestStepRegistry.entries.entries) {
        final path = SessionStepRouting.pathFor(e.key);
        expect(path, isNotNull, reason: e.key);
        expect(
          path,
          YamlStepMigrationMatrix.pathFor(e.key),
          reason: e.key,
        );
      }
    });

    test('ui action capabilities match registry-derived act paths', () {
      final derived = SessionStepRouting.uiActionNames();
      expect(derived, isNotEmpty);
      expect(SessionCapabilities.local.actions, derived);
      expect(SessionPermissions.yamlController.actions, derived);
      expect(
        SessionPermissions.restrictedUi.actions,
        derived.difference(SessionStepRouting.restrictedUiExclusions),
      );
      for (final name in derived) {
        expect(
          SessionStepRouting.pathFor(name),
          YamlStepPath.act,
          reason: name,
        );
      }
    });

    test('unknown operations have no routing', () {
      expect(YamlStepMigrationMatrix.pathFor('pinchZoom'), isNull);
      expect(SessionStepRouting.pathFor('notARealStep'), isNull);
    });
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
}
