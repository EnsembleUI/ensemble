import 'dart:convert';
import 'dart:io';

/// Runtime settings for one CLI worker.
///
/// Worker-specific settings are passed through the process environment so
/// they do not produce a distinct Flutter test kernel for every shard. Existing
/// dart-define values remain the fallback for direct and device test launches.
final class RunnerRuntimeConfiguration {
  RunnerRuntimeConfiguration.fromEnvironment(Map<String, String> environment)
      : _values = _decode(environment[_environmentKey]);

  static const _environmentKey = 'ENSEMBLE_TEST_RUNNER_CONFIG';

  static final current = RunnerRuntimeConfiguration.fromEnvironment(
    Platform.environment,
  );

  final Map<String, dynamic> _values;

  String string(String name, {String defaultValue = ''}) {
    final value = _values[name];
    if (value is String) return value;
    return String.fromEnvironment(name, defaultValue: defaultValue);
  }

  int integer(String name, {int defaultValue = 0}) {
    final value = _values[name];
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return int.fromEnvironment(name, defaultValue: defaultValue);
  }

  List<String> strings(String name) {
    final value = _values[name];
    if (value is List) return value.map((item) => item.toString()).toList();
    final fallback = String.fromEnvironment(name);
    return fallback.isEmpty ? const [] : fallback.split(',');
  }

  static Map<String, dynamic> _decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const {};
    final decoded = json.decode(encoded);
    if (decoded is! Map) {
      throw const FormatException(
          'Runner runtime configuration must be an object.');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
