import 'dart:collection';
import 'dart:convert';

import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:yaml/yaml.dart';

Future<String> writeApiCallsLog(EnsembleTestContext context) {
  return writeApiCallsLogFile(
    logger: context.logger,
    filePrefix: context.runtime.artifactFilePrefix(context.testCase.id),
    calls: context.apiOverlay.calls,
  );
}

Future<String> writeApiCallsLogFile({
  required TestLogger logger,
  required String filePrefix,
  required List<APICallRecord> calls,
}) {
  return RunnerBenchmark.future('diagnostic', 'writeApiCallsLogFile', () {
    final callsByName = <String, List<DateTime>>{};
    for (final call in calls) {
      callsByName
          .putIfAbsent(call.name, () => <DateTime>[])
          .add(call.timestamp);
    }
    Map<String, dynamic> eventFor(
      APICallRecord call,
      int index, {
      int? stepIndex,
      DateTime? timestamp,
      bool? completed,
      bool includeResponse = true,
      bool includeOutcome = true,
      String? phase,
      bool overrideStepIndex = false,
    }) {
      return {
        'index': index,
        'callId': index,
        'name': call.name,
        'timestamp': (timestamp ?? call.timestamp).toIso8601String(),
        if ((overrideStepIndex ? stepIndex : stepIndex ?? call.stepIndex) !=
            null)
          'stepIndex':
              overrideStepIndex ? stepIndex : stepIndex ?? call.stepIndex,
        if (call.mocked != null) 'mocked': call.mocked,
        if (includeOutcome && call.statusCode != null)
          'statusCode': call.statusCode,
        if (includeOutcome && call.error != null) 'error': call.error,
        'completed': completed ?? call.isCompleted,
        if (includeOutcome && call.providerDurationMs != null)
          'providerDurationMs': call.providerDurationMs,
        if (phase != null) 'phase': phase,
        if (includeResponse && (call.isCompleted || call.responseBody != null))
          'responseBody': _loggableResponseBody(call.responseBody),
        if (call.type != null) 'type': call.type,
        'request': {
          'url': (call.resolvedUrl?.isNotEmpty == true)
              ? call.resolvedUrl!
              : (call.type == 'firestore'
                  ? ((call.apiDefinition['path'] ??
                              call.apiDefinition['firestore']?['path'])
                          ?.toString() ??
                      '')
                  : (call.type == 'functions'
                      ? ((call.apiDefinition['name'] ??
                                  call.apiDefinition['function']?['name'])
                              ?.toString() ??
                          '')
                      : (call.apiDefinition['url'] ?? call.apiDefinition['uri'])
                              ?.toString() ??
                          '')),
          'method': call.type == 'firestore'
              ? ((call.apiDefinition['operation'] ??
                          call.apiDefinition['firestore']?['operation'])
                      ?.toString()
                      .toUpperCase() ??
                  'GET')
              : (call.type == 'functions'
                  ? 'CALL'
                  : (call.apiDefinition['method']?.toString() ?? 'GET')),
          if (call.resolvedHeaders != null ||
              call.apiDefinition['headers'] != null ||
              call.apiDefinition['firestore']?['headers'] != null ||
              call.apiDefinition['function']?['headers'] != null)
            'headers': call.resolvedHeaders ??
                call.apiDefinition['headers'] ??
                call.apiDefinition['firestore']?['headers'] ??
                call.apiDefinition['function']?['headers'],
          if (call.resolvedBody != null ||
              call.apiDefinition['body'] != null ||
              call.apiDefinition['data'] != null ||
              call.apiDefinition['firestore']?['body'] != null ||
              call.apiDefinition['firestore']?['data'] != null ||
              call.apiDefinition['function']?['body'] != null ||
              call.apiDefinition['function']?['data'] != null)
            'body': call.resolvedBody ??
                call.apiDefinition['body'] ??
                call.apiDefinition['data'] ??
                call.apiDefinition['firestore']?['body'] ??
                call.apiDefinition['firestore']?['data'] ??
                call.apiDefinition['function']?['body'] ??
                call.apiDefinition['function']?['data'],
          if (call.resolvedParameters != null ||
              call.apiDefinition['parameters'] != null ||
              call.apiDefinition['query'] != null ||
              call.apiDefinition['firestore']?['parameters'] != null ||
              call.apiDefinition['firestore']?['query'] != null ||
              call.apiDefinition['function']?['parameters'] != null ||
              call.apiDefinition['function']?['query'] != null)
            'parameters': call.resolvedParameters ??
                call.apiDefinition['parameters'] ??
                call.apiDefinition['query'] ??
                call.apiDefinition['firestore']?['parameters'] ??
                call.apiDefinition['firestore']?['query'] ??
                call.apiDefinition['function']?['parameters'] ??
                call.apiDefinition['function']?['query'],
        },
      };
    }

    final events = <Map<String, dynamic>>[];
    for (var i = 0; i < calls.length; i++) {
      final call = calls[i];
      final wasPendingAtStepEnd = call.wasPendingAtStepEnd;
      if (!wasPendingAtStepEnd) {
        events.add(eventFor(call, i + 1));
        continue;
      }
      if (call.isCompleted && call.completionStepIndex == call.stepIndex) {
        // The request and response both occurred inside this step. It is one
        // completed call in that step, not a cross-step pending/response pair.
        events.add(eventFor(call, i + 1));
        continue;
      }
      // Preserve the end-of-step observation even if the response eventually
      // arrived (or the test ended) before the report was written.
      events.add(eventFor(
        call,
        i + 1,
        stepIndex: call.stepIndex,
        completed: false,
        includeResponse: false,
        includeOutcome: false,
        phase: 'pending',
      ));
      if (!call.isCompleted) continue;

      // The later response is a separate event on the step where the provider
      // actually completed. A null step means it completed between steps.
      events.add(eventFor(
        call,
        i + 1,
        stepIndex: call.completionStepIndex,
        timestamp: call.completedAt,
        phase: 'completed',
        overrideStepIndex: true,
      ));
    }
    final content = const JsonEncoder.withIndent('  ').convert(
      _toSerializable({
        'total': calls.length,
        'calls': callsByName.entries
            .map(
              (entry) => {
                'name': entry.key,
                'count': entry.value.length,
                'timestamps': [
                  for (final timestamp in entry.value)
                    timestamp.toIso8601String(),
                ],
              },
            )
            .toList(),
        'events': events,
      }),
    );

    return logger.writeLogFile(
      testId: filePrefix,
      name: 'api_calls',
      content: content,
      extension: 'json',
    );
  });
}

Future<String> writeStorageLog(
  EnsembleTestContext context, {
  String? key,
}) {
  return writeStorageLogFile(
    logger: context.logger,
    filePrefix: context.testCase.id,
    key: key,
    stepDiffs: context.runtime.storageStepDiffs,
    secureStepDiffs: context.runtime.secureStorageStepDiffs,
    keychainStepDiffs: context.runtime.keychainStepDiffs,
  );
}

Future<String> writeAppConsoleLog(EnsembleTestContext context) {
  return RunnerBenchmark.future('diagnostic', 'writeAppConsoleLog', () {
    final buffer = StringBuffer();
    if (context.runtime.attemptCount > 1) {
      buffer.writeln(
        '--- Attempt ${context.runtime.attemptNumber} of '
        '${context.runtime.attemptCount} ---',
      );
    }
    for (final line in context.runtime.consoleLogs) {
      buffer.writeln(line);
    }
    if (context.runtime.flutterErrors.isNotEmpty) {
      if (buffer.isNotEmpty) {
        buffer.writeln();
      }
      buffer.writeln('--- flutter errors ---');
      for (final error in context.runtime.flutterErrors) {
        buffer.writeln(error);
      }
    }
    return context.logger.writeLogFile(
      testId: context.runtime.artifactFilePrefix(context.testCase.id),
      name: 'app_console',
      content: buffer.isEmpty ? '<no console output>\n' : buffer.toString(),
      extension: 'log',
    );
  });
}

Future<String> writeStorageLogFile({
  required TestLogger logger,
  required String filePrefix,
  String? key,
  List<StorageStepDiff> stepDiffs = const [],
  List<StorageStepDiff> secureStepDiffs = const [],
  List<StorageStepDiff> keychainStepDiffs = const [],
  Map<String, dynamic>? keys,
  Map<String, dynamic>? secureStorageKeys,
  Map<String, dynamic>? keychainKeys,
}) async {
  return await RunnerBenchmark.async('diagnostic', 'writeStorageLogFile',
      () async {
    if (key != null && key.isNotEmpty) {
      return logger.writeLogFile(
        testId: filePrefix,
        name: 'storage_$key',
        content: _prettyJson(StorageManager().read(key)),
        extension: 'json',
      );
    }

    final snapshot = keys ?? capturePublicStorage();
    final contentMap = <String, dynamic>{
      'storage': {
        'keys': snapshot,
        'steps': [for (final diff in stepDiffs) diff.toJson()],
      },
      'secureStorage': {
        'keys': secureStorageKeys ??
            (keys == null ? captureSecureStorage() : <String, dynamic>{}),
        'steps': [
          for (final diff in secureStepDiffs) diff.toJson(),
        ],
      },
      'keychain': {
        'keys': keychainKeys ??
            (keys == null
                ? await captureKeychainStorage()
                : <String, dynamic>{}),
        'steps': [
          for (final diff in keychainStepDiffs) diff.toJson(),
        ],
      },
    };
    final content = _prettyJson(contentMap);
    return logger.writeLogFile(
      testId: filePrefix,
      name: 'storage',
      content: content,
      extension: 'json',
    );
  });
}

String _prettyJson(Object? value) {
  return const JsonEncoder.withIndent('  ').convert(_toSerializable(value));
}

Object? _loggableResponseBody(Object? value) {
  return _toSerializable(value);
}

/// Recursively converts values into JSON-safe primitives.
///
/// Ensemble runtime objects (e.g. [EnsembleFieldValue], other Invokables) are
/// not JsonCodec-encodable; falling back to [Object.toString] keeps artifact
/// writes from failing after an otherwise-passing test.
dynamic _toSerializable(dynamic value) =>
    _toSerializableNested(value, HashSet<Object>.identity(), 0);

const _maxDiagnosticNesting = 64;
const _circularDiagnosticValue = '<circular reference>';

dynamic _toSerializableNested(
  dynamic value,
  Set<Object> ancestors,
  int depth,
) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (depth >= _maxDiagnosticNesting) return '<maximum nesting reached>';
  if (value is Map || value is Iterable) {
    if (!ancestors.add(value as Object)) return _circularDiagnosticValue;
    try {
      return _serializeCollection(value, ancestors, depth + 1);
    } finally {
      ancestors.remove(value);
    }
  }
  try {
    return value.toString();
  } catch (_) {
    return '<unprintable ${value.runtimeType}>';
  }
}

dynamic _serializeCollection(Object value, Set<Object> ancestors, int depth) {
  if (value is YamlMap) {
    return {
      for (final entry in value.entries)
        entry.key.toString():
            _toSerializableNested(entry.value, ancestors, depth),
    };
  }
  if (value is YamlList) {
    return [
      for (final item in value) _toSerializableNested(item, ancestors, depth)
    ];
  }
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString():
            _toSerializableNested(entry.value, ancestors, depth),
    };
  }
  if (value is List) {
    return [
      for (final item in value) _toSerializableNested(item, ancestors, depth)
    ];
  }
  if (value is Iterable) {
    return [
      for (final item in value) _toSerializableNested(item, ancestors, depth)
    ];
  }
  return value.toString();
}
