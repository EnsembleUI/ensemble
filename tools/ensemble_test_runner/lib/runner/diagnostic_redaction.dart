/// Redaction helpers for diagnostic artifacts.
///
/// Redaction is applied at publication time so assertions and the in-memory
/// runtime retain the original values.
const String diagnosticRedactedValue = '<redacted>';

const _sensitiveKeyNames = <String>{
  'access_token',
  'apikey',
  'api_key',
  'authorization',
  'client_secret',
  'cookie',
  'credential',
  'credentials',
  'id_token',
  'password',
  'passwd',
  'refresh_token',
  'secret',
  'set_cookie',
  'token',
};

/// Recursively removes common credential values while preserving payload shape.
Object? redactDiagnosticValue(Object? value) {
  if (value == null || value is num || value is bool) return value;
  if (value is String) return redactDiagnosticText(value);
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _isSensitiveKey(entry.key.toString())
            ? diagnosticRedactedValue
            : redactDiagnosticValue(entry.value),
    };
  }
  if (value is Iterable) {
    return [for (final item in value) redactDiagnosticValue(item)];
  }
  return redactDiagnosticText(value.toString());
}

/// Redacts credentials embedded in human-readable log lines and URLs.
String redactDiagnosticText(String value) {
  final redacted = value.replaceAllMapped(
    RegExp(
      r'''(authorization|cookie|password|passwd|secret|token|api[_-]?key)'''
      r'''(["']?\s*[:=]\s*["']?)((?:bearer\s+)?[^\s,;}&"'\]]+)''',
      caseSensitive: false,
    ),
    (match) {
      final raw = match.group(3)!;
      final value = raw.toLowerCase().startsWith('bearer ')
          ? 'Bearer $diagnosticRedactedValue'
          : diagnosticRedactedValue;
      return '${match.group(1)}${match.group(2)}$value';
    },
  );
  return redacted.replaceAllMapped(
    RegExp(r'''(bearer\s+)[^\s,;}"'\]]+''', caseSensitive: false),
    (match) => '${match.group(1)}$diagnosticRedactedValue',
  );
}

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  return _sensitiveKeyNames
          .map((name) => name.replaceAll('_', ''))
          .contains(normalized) ||
      normalized.endsWith('authorization') ||
      normalized.endsWith('apikey') ||
      normalized.endsWith('token') ||
      normalized.endsWith('secret') ||
      normalized.endsWith('password');
}
