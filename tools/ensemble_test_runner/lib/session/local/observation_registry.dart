import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/leaf_command_queue.dart';
import 'package:ensemble_test_runner/session/local/observable_fingerprint.dart';
import 'package:ensemble_test_runner/session/observation/ui_element.dart';
import 'package:flutter/widgets.dart';

/// Internal handle binding a snapshot [elementId] to a live [Element].
class SnapshotElementHandle {
  final String observationId;
  final String elementId;
  final String? testId;
  final Element element;
  final String observableFingerprint;

  SnapshotElementHandle({
    required this.observationId,
    required this.elementId,
    required this.testId,
    required this.element,
    required this.observableFingerprint,
  });

  bool get isMounted {
    try {
      return element.mounted;
    } catch (_) {
      return false;
    }
  }
}

/// Maps observation/element ids to live handles with bounded retention.
class ObservationRegistry {
  ObservationRegistry({this.maxObservations = 3});

  final int maxObservations;
  final Map<String, Map<String, SnapshotElementHandle>> _byObservation = {};
  late final BoundedObservationIds _lru =
      BoundedObservationIds(capacity: maxObservations);

  void registerObservation({
    required String observationId,
    required Map<String, SnapshotElementHandle> handles,
  }) {
    _byObservation[observationId] = Map.unmodifiable(handles);
    for (final dropped in _lru.remember(observationId)) {
      _byObservation.remove(dropped);
    }
  }

  SnapshotElementHandle resolve({
    required String observationId,
    required String elementId,
  }) {
    final handles = _byObservation[observationId];
    if (handles == null) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.staleObservation,
        message:
            'Observation "$observationId" is no longer retained or never existed.',
        details: {'observationId': observationId, 'elementId': elementId},
      );
    }
    final handle = handles[elementId];
    if (handle == null) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.elementNotFound,
        message:
            'Element "$elementId" was not found in observation "$observationId".',
        details: {'observationId': observationId, 'elementId': elementId},
      );
    }
    return handle;
  }

  /// For snapshot targets, mount-check only on the cached Element.
  /// Observable fingerprint staleness is enforced when the controller
  /// re-observes; immediate content drift is still caught if the Element is
  /// defunct. Full fingerprint compare uses [liveFingerprint] when provided
  /// values differ from storage (callers should pass matching digests).
  SnapshotElementHandle revalidate({
    required String observationId,
    required String elementId,
    String Function(Element element, String? testId)? liveFingerprint,
  }) {
    final handle = resolve(
      observationId: observationId,
      elementId: elementId,
    );
    if (!handle.isMounted) {
      throw TestExecutionError(
        code: TestExecutionErrorCode.staleObservation,
        message:
            'Element "$elementId" from observation "$observationId" is detached.',
        details: {'observationId': observationId, 'elementId': elementId},
      );
    }
    if (liveFingerprint != null) {
      final live = liveFingerprint(handle.element, handle.testId);
      if (live != handle.observableFingerprint) {
        throw TestExecutionError(
          code: TestExecutionErrorCode.staleObservation,
          message:
              'Element "$elementId" observable state changed since observation '
              '"$observationId".',
          details: {
            'observationId': observationId,
            'elementId': elementId,
            'expectedFingerprint': handle.observableFingerprint,
            'liveFingerprint': live,
          },
        );
      }
    }
    return handle;
  }

  void clear() {
    _byObservation.clear();
    _lru.clear();
  }

  /// Exposed for tests.
  bool containsObservation(String observationId) =>
      _byObservation.containsKey(observationId);
}

/// Builds a [UiElement] fingerprint string for registry storage.
String handleFingerprintForUiElement(UiElement element) =>
    fingerprintForElement(element);
