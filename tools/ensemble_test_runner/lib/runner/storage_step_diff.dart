import 'dart:convert';

import 'package:ensemble/framework/storage_manager.dart';

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

  Map<String, dynamic> toJson() => {
        'key': key,
        'change': change,
        if (before != null) 'before': before,
        if (after != null) 'after': after,
      };
}

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

  Map<String, dynamic> toJson() => {
        'stepIndex': stepIndex,
        'timestamp': timestamp.toIso8601String(),
        'changes': [for (final c in changes) c.toJson()],
      };
}

/// Deep-copies current public [StorageManager] keys into a plain map.
Map<String, dynamic> capturePublicStorage() {
  final storage = StorageManager();
  final result = <String, dynamic>{};
  for (final key in storage.getKeys()) {
    result[key] = _copy(storage.read(key));
  }
  return result;
}

/// Diff of public storage maps. Returns only keys that changed.
List<StorageKeyChange> diffStorage(
  Map<String, dynamic> before,
  Map<String, dynamic> after,
) {
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
