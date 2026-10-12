import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'dart:convert';

import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/encrypted_storage_manager.dart';
import 'package:ensemble_test_runner/src/core/kernel.dart';

/// Storage state captured before a test step for later diagnostic diffing.
final class StorageStepSnapshot {
  const StorageStepSnapshot({
    required this.publicValues,
    required this.secureValues,
    required this.keychainValues,
  });

  final Map<String, dynamic> publicValues;
  final Map<String, dynamic> secureValues;
  final Map<String, dynamic> keychainValues;
}

/// Captures storage only when storage diagnostics are enabled.
///
/// Returning `null` means the step must not capture a follow-up snapshot or
/// calculate a diff. This keeps the disabled path free of storage work.
Future<StorageStepSnapshot?> captureStorageStepSnapshot({
  required bool enabled,
}) async {
  if (!enabled) return null;
  return StorageStepSnapshot(
    publicValues: capturePublicStorage(),
    secureValues: captureSecureStorage(),
    keychainValues: await captureKeychainStorage(),
  );
}

/// One public-storage key change during a test step.
class StorageKeyChange {
  final String key;
  final String change; // added | modified | removed
  final Object? before;
  final Object? after;

  const StorageKeyChange({
    required this.key,
    required this.change,
    this.before,
    this.after,
  });

  /// Serializes one change for an artifact.
  ///
  /// Secure-storage changes can hide values while retaining their keys.
  /// Keychain artifact serialization keeps values so reports show the captured
  /// platform state.
  Map<String, dynamic> toJson({bool redactValues = false}) => {
        'key': key,
        'change': change,
        if (before != null)
          'before': redactValues ? redactedSecureStorageValue : before,
        if (after != null)
          'after': redactValues ? redactedSecureStorageValue : after,
      };
}

/// Stable marker used for values that must never leave the runner process.
const String redactedSecureStorageValue = '<redacted>';

/// Keeps secure storage keys for diagnostics while removing every value.
Map<String, dynamic> redactSecureStorageValues(Map<String, dynamic> values) => {
      for (final key in values.keys) key: redactedSecureStorageValue,
    };

/// Public-storage diff attributed to one top-level step.
class StorageStepDiff {
  final int stepIndex;
  final DateTime timestamp;
  final List<StorageKeyChange> changes;

  const StorageStepDiff({
    required this.stepIndex,
    required this.timestamp,
    required this.changes,
  });

  Map<String, dynamic> toJson({bool redactValues = false}) => {
        'stepIndex': stepIndex,
        'timestamp': timestamp.toIso8601String(),
        'changes': [
          for (final c in changes) c.toJson(redactValues: redactValues),
        ],
      };
}

/// Deep-copies current public [StorageManager] keys into a plain map.
Map<String, dynamic> capturePublicStorage() {
  return RunnerBenchmark.sync('lifecycle', 'capturePublicStorage', () {
    final storage = StorageManager();
    final result = <String, dynamic>{};
    for (final key in storage.getKeys()) {
      if (!key.startsWith('enc_')) {
        result[key] = _copy(storage.read(key));
      }
    }
    return result;
  });
}

/// Captures Ensemble encrypted public-storage values using their logical keys.
///
/// The encrypted backend stores values under `enc_<key>` in public GetStorage.
/// Reports expose the logical key and decoded value instead.
Map<String, dynamic> captureSecureStorage() {
  return RunnerBenchmark.sync('lifecycle', 'captureSecureStorage', () {
    final storage = StorageManager();
    final result = <String, dynamic>{};
    for (final backendKey in storage.getKeys()) {
      if (!backendKey.startsWith('enc_')) continue;
      final key = backendKey.substring('enc_'.length);
      final raw = storage.read(backendKey);
      final decoded = EncryptedStorageManager.getSecureStorage(key);
      result[key] = decoded ??
          <String, dynamic>{
            'value': _copy(raw),
            'decodeError': true,
          };
    }
    return result;
  });
}

/// Captures platform keychain / FlutterSecureStorage values.
Future<Map<String, dynamic>> captureKeychainStorage() async {
  return await RunnerBenchmark.async('lifecycle', 'captureKeychainStorage',
      () async {
    final values = await StorageManager().getAllFromKeychain();
    return {
      for (final entry in values.entries) entry.key: _copy(entry.value),
    };
  });
}

/// Diff of public storage maps. Returns only keys that changed.
List<StorageKeyChange> diffStorage(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
  return RunnerBenchmark.sync('lifecycle', 'diffStorage', () {
    final changes = <StorageKeyChange>[];
    final allKeys = {...before.keys, ...after.keys};
    for (final key in allKeys.toList()..sort()) {
      final hadBefore = before.containsKey(key);
      final hadAfter = after.containsKey(key);
      if (!hadBefore && hadAfter) {
        changes.add(
          StorageKeyChange(key: key, change: 'added', after: after[key]),
        );
      } else if (hadBefore && !hadAfter) {
        changes.add(
          StorageKeyChange(key: key, change: 'removed', before: before[key]),
        );
      } else if (!_deepEquals(before[key], after[key])) {
        changes.add(
          StorageKeyChange(
            key: key,
            change: 'modified',
            before: before[key],
            after: after[key],
          ),
        );
      }
    }
    return changes;
  });
}

dynamic _copy(dynamic value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _copy(entry.value),
    };
  }
  if (value is List) {
    return [for (final item in value) _copy(item)];
  }
  if (value is Iterable) {
    return [for (final item in value) _copy(item)];
  }
  try {
    return jsonDecode(jsonEncode(value));
  } catch (_) {
    return value.toString();
  }
}

bool _deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  try {
    return jsonEncode(_copy(a)) == jsonEncode(_copy(b));
  } catch (_) {
    return a == b;
  }
}

/// Captures and persists storage diffs at authored step event boundaries.
///
/// Disabled diagnostics return before any storage access. A caller may flush
/// the active step when execution fails before a matching `stepFinished`
/// event, preserving evidence for partially completed steps.
final class StorageStepDiffSubscriber {
  StorageStepDiffSubscriber({
    required this.enabled,
    required Future<void> Function(int stepIndex, StorageStepSnapshot before)
        recordDiff,
    Future<StorageStepSnapshot?> Function()? capture,
  })  : _recordDiff = recordDiff,
        _capture =
            capture ?? (() => captureStorageStepSnapshot(enabled: enabled));

  final bool enabled;
  final Future<void> Function(int, StorageStepSnapshot) _recordDiff;
  final Future<StorageStepSnapshot?> Function() _capture;
  final Map<int, StorageStepSnapshot> _snapshots = {};

  Future<void> call(ExecutionEvent event) async {
    if (!enabled) return;
    if (event.kind == ExecutionEventKind.attemptFinished) {
      // Failed or cancelled attempts may end with an active step that never
      // publishes stepFinished. Flush those snapshots from the same ordered
      // stream so normal and interrupted report paths share one owner.
      await flushAll();
      return;
    }
    if (event.stepIndex == null) return;
    final index = event.stepIndex!;
    switch (event.kind) {
      case ExecutionEventKind.stepStarted:
        final snapshot = await _capture();
        if (snapshot != null) _snapshots[index] = snapshot;
      case ExecutionEventKind.stepFinished:
        // Normal completion is owned by the event stream. Lifecycle cleanup
        // may still call flush for failure/compatibility paths, but the
        // snapshot is removed here so it cannot be persisted twice.
        await flush(index);
      default:
        break;
    }
  }

  Future<void> flush(int stepIndex) async {
    final snapshot = _snapshots.remove(stepIndex);
    if (snapshot != null) await _recordDiff(stepIndex, snapshot);
  }

  Future<void> flushAll() async {
    for (final stepIndex in _snapshots.keys.toList()) {
      await flush(stepIndex);
    }
  }
}
