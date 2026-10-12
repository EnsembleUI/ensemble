import 'dart:convert';

/// Compares assertion values after normalizing the representations commonly
/// produced by YAML and runtime APIs.
///
/// This is deliberately independent from Flutter so assertion value semantics
/// can be reused and tested without constructing a widget tree.
final class AssertionValueComparison {
  const AssertionValueComparison._();

  static bool deepEquals(dynamic left, dynamic right) {
    if (left == right) return true;

    final normalizedLeft = _normalize(left);
    final normalizedRight = _normalize(right);

    if (normalizedLeft is Map && normalizedRight is Map) {
      if (normalizedLeft.length != normalizedRight.length) return false;
      for (final key in normalizedLeft.keys) {
        if (!normalizedRight.containsKey(key)) return false;
        if (!deepEquals(normalizedLeft[key], normalizedRight[key])) {
          return false;
        }
      }
      return true;
    }

    if (normalizedLeft is List && normalizedRight is List) {
      if (normalizedLeft.length != normalizedRight.length) return false;
      for (var index = 0; index < normalizedLeft.length; index++) {
        if (!deepEquals(normalizedLeft[index], normalizedRight[index])) {
          return false;
        }
      }
      return true;
    }

    return false;
  }

  static dynamic _normalize(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map(
        (key, nestedValue) => MapEntry(key.toString(), _normalize(nestedValue)),
      );
    }
    if (value is List) return value.map(_normalize).toList();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return _normalize(json.decode(trimmed));
        } catch (_) {
          // Keep malformed JSON-like text as a plain string.
        }
      }
    }
    return value;
  }
}
