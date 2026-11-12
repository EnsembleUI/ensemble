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

  // `String.fromEnvironment` is only guaranteed to read a compile-time value
  // when its name is a constant expression. A dynamic call such as
  // `String.fromEnvironment(name)` silently falls back to the default, which
  // made CLI options like `--id` disappear in application-owned test entries.
  // Keep the supported Flutter defines in one literal-keyed map.
  static const _compileTimeValues = <String, String>{
    'ensembleTestEncryptionKey':
        String.fromEnvironment('ensembleTestEncryptionKey'),
    'ensembleTestArtifactRoot':
        String.fromEnvironment('ensembleTestArtifactRoot'),
    'ensembleTestArtifactDisplayRoot':
        String.fromEnvironment('ensembleTestArtifactDisplayRoot'),
    'ensembleTestExecutionMode':
        String.fromEnvironment('ensembleTestExecutionMode'),
    'ensembleTestWorkerIndex':
        String.fromEnvironment('ensembleTestWorkerIndex'),
    'ensembleTestWorkerSuffix':
        String.fromEnvironment('ensembleTestWorkerSuffix'),
    'ensembleTestShardPath':
        String.fromEnvironment('ensembleTestShardPath'),
    'ensembleTestShardId':
        String.fromEnvironment('ensembleTestShardId'),
    'ensembleTestReport': String.fromEnvironment('ensembleTestReport'),
    'ensembleTestReportFile':
        String.fromEnvironment('ensembleTestReportFile'),
    'ensembleTestTimeoutSeconds':
        String.fromEnvironment('ensembleTestTimeoutSeconds'),
    'ensembleTestProgressFile':
        String.fromEnvironment('ensembleTestProgressFile'),
    'ensembleTestAppLogFile':
        String.fromEnvironment('ensembleTestAppLogFile'),
    'ensembleTestAppLogDisplayFile':
        String.fromEnvironment('ensembleTestAppLogDisplayFile'),
    'ensembleTestServiceOverrides':
        String.fromEnvironment('ensembleTestServiceOverrides'),
    'ensembleTestId': String.fromEnvironment('ensembleTestId'),
    'ensembleTestFeature': String.fromEnvironment('ensembleTestFeature'),
    'ensembleTestProfile': String.fromEnvironment('ensembleTestProfile'),
    'ensembleTestTag': String.fromEnvironment('ensembleTestTag'),
    'ensembleTestPath': String.fromEnvironment('ensembleTestPath'),
    'ensembleTestDevice': String.fromEnvironment('ensembleTestDevice'),
    'ensembleTestInputs': String.fromEnvironment('ensembleTestInputs'),
    'ensembleTestPlanBatchFile':
        String.fromEnvironment('ensembleTestPlanBatchFile'),
  };

  final Map<String, dynamic> _values;

  String string(String name, {String defaultValue = ''}) {
    final value = _values[name];
    if (value is String) return value;
    final compileTimeValue = _compileTimeValues[name];
    return compileTimeValue == null || compileTimeValue.isEmpty
        ? defaultValue
        : compileTimeValue;
  }

  int integer(String name, {int defaultValue = 0}) {
    final value = _values[name];
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
    return int.tryParse(_compileTimeValues[name] ?? '') ?? defaultValue;
  }

  List<String> strings(String name) {
    final value = _values[name];
    if (value is List) return value.map((item) => item.toString()).toList();
    final fallback = _compileTimeValues[name] ?? '';
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
