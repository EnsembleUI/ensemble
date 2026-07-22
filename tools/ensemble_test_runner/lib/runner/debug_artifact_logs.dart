import 'dart:convert';

import 'package:yaml/yaml.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:flutter/material.dart';

Future<String> writeDumpTreeLog(EnsembleTestContext context) {
  return writeDumpTreeLogFile(
    logger: context.logger,
    filePrefix: context.testCase.id,
  );
}

Future<String> writeDumpTreeLogFile({
  required TestLogger logger,
  required String filePrefix,
}) {
  return logger.writeLogFile(
    testId: filePrefix,
    name: 'dump_tree',
    content: captureDebugDumpApp(),
    extension: 'txt',
  );
}

Future<String> writeApiCallsLog(EnsembleTestContext context) {
  return writeApiCallsLogFile(
    logger: context.logger,
    filePrefix: context.testCase.id,
    calls: context.apiOverlay.calls,
  );
}

Future<String> writeApiCallsLogFile({
  required TestLogger logger,
  required String filePrefix,
  required List<APICallRecord> calls,
}) {
  final callsByName = <String, List<DateTime>>{};
  for (final call in calls) {
    callsByName.putIfAbsent(call.name, () => <DateTime>[]).add(call.timestamp);
  }
  final content = const JsonEncoder.withIndent('  ').convert({
    'total': calls.length,
    'calls': callsByName.entries
        .map(
          (entry) => {
            'name': entry.key,
            'count': entry.value.length,
            'timestamps': [
              for (final timestamp in entry.value) timestamp.toIso8601String(),
            ],
          },
        )
        .toList(),
    'events': [
      for (var i = 0; i < calls.length; i++)
        {
          'index': i + 1,
          'name': calls[i].name,
          'timestamp': calls[i].timestamp.toIso8601String(),
          if (calls[i].stepIndex != null) 'stepIndex': calls[i].stepIndex,
          if (calls[i].mocked != null) 'mocked': calls[i].mocked,
          if (calls[i].statusCode != null) 'statusCode': calls[i].statusCode,
          if (calls[i].error != null) 'error': calls[i].error,
          if (calls[i].responseBody != null)
            'responseBody': _loggableResponseBody(calls[i].responseBody),
          if (calls[i].type != null) 'type': calls[i].type,
          'request': {
            'url': (calls[i].resolvedUrl?.isNotEmpty == true)
                ? calls[i].resolvedUrl!
                : (calls[i].type == 'firestore'
                    ? ((calls[i].apiDefinition['path'] ??
                            calls[i].apiDefinition['firestore']?['path'])
                        ?.toString() ??
                        '')
                    : (calls[i].type == 'functions'
                        ? ((calls[i].apiDefinition['name'] ??
                                calls[i].apiDefinition['function']?['name'])
                            ?.toString() ??
                            '')
                        : (calls[i].apiDefinition['url'] ??
                                calls[i].apiDefinition['uri'])
                            ?.toString() ??
                            '')),
            'method': calls[i].type == 'firestore'
                ? ((calls[i].apiDefinition['operation'] ??
                        calls[i].apiDefinition['firestore']?['operation'])
                    ?.toString()
                    .toUpperCase() ??
                    'GET')
                : (calls[i].type == 'functions'
                    ? 'CALL'
                    : (calls[i].apiDefinition['method']?.toString() ?? 'GET')),
            if (calls[i].apiDefinition['headers'] != null ||
                calls[i].apiDefinition['firestore']?['headers'] != null ||
                calls[i].apiDefinition['function']?['headers'] != null)
              'headers': _toSerializable(
                  calls[i].apiDefinition['headers'] ??
                  calls[i].apiDefinition['firestore']?['headers'] ??
                  calls[i].apiDefinition['function']?['headers']
              ),
            if (calls[i].apiDefinition['body'] != null ||
                calls[i].apiDefinition['data'] != null ||
                calls[i].apiDefinition['firestore']?['body'] != null ||
                calls[i].apiDefinition['firestore']?['data'] != null ||
                calls[i].apiDefinition['function']?['body'] != null ||
                calls[i].apiDefinition['function']?['data'] != null)
              'body': _toSerializable(
                  calls[i].apiDefinition['body'] ??
                  calls[i].apiDefinition['data'] ??
                  calls[i].apiDefinition['firestore']?['body'] ??
                  calls[i].apiDefinition['firestore']?['data'] ??
                  calls[i].apiDefinition['function']?['body'] ??
                  calls[i].apiDefinition['function']?['data']
              ),
            if (calls[i].apiDefinition['parameters'] != null ||
                calls[i].apiDefinition['query'] != null ||
                calls[i].apiDefinition['firestore']?['parameters'] != null ||
                calls[i].apiDefinition['firestore']?['query'] != null ||
                calls[i].apiDefinition['function']?['parameters'] != null ||
                calls[i].apiDefinition['function']?['query'] != null)
              'parameters': _toSerializable(
                  calls[i].apiDefinition['parameters'] ??
                  calls[i].apiDefinition['query'] ??
                  calls[i].apiDefinition['firestore']?['parameters'] ??
                  calls[i].apiDefinition['firestore']?['query'] ??
                  calls[i].apiDefinition['function']?['parameters'] ??
                  calls[i].apiDefinition['function']?['query']
              ),
          },
        },
    ],
  });

  return logger.writeLogFile(
    testId: filePrefix,
    name: 'api_calls',
    content: content,
    extension: 'json',
  );
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
  );
}

Future<String> writeAppConsoleLog(EnsembleTestContext context) {
  final buffer = StringBuffer();
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
    testId: context.testCase.id,
    name: 'app_console',
    content: buffer.isEmpty ? '<no console output>\n' : buffer.toString(),
    extension: 'log',
  );
}

Future<String> writeStorageLogFile({
  required TestLogger logger,
  required String filePrefix,
  String? key,
  List<StorageStepDiff> stepDiffs = const [],
  Map<String, dynamic>? keys,
}) {
  if (key != null && key.isNotEmpty) {
    return logger.writeLogFile(
      testId: filePrefix,
      name: 'storage_$key',
      content: _prettyJson(StorageManager().read(key)),
      extension: 'json',
    );
  }

  final snapshot = keys ?? <String, dynamic>{
    for (final storageKey in StorageManager().getKeys())
      storageKey: StorageManager().read(storageKey),
  };
  final content = _prettyJson({
    'keys': snapshot,
    'steps': [for (final diff in stepDiffs) diff.toJson()],
  });
  return logger.writeLogFile(
    testId: filePrefix,
    name: 'storage',
    content: content,
    extension: 'json',
  );
}

String captureDebugDumpApp() {
  final previousDebugPrint = debugPrint;
  final lines = <String>[];
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      lines.add(message);
    }
  };
  try {
    debugDumpApp();
  } finally {
    debugPrint = previousDebugPrint;
  }
  if (lines.isEmpty) {
    return '<empty widget tree>';
  }
  return lines.join('\n');
}

String _prettyJson(Object? value) {
  return JsonEncoder.withIndent('  ', (value) => value.toString())
      .convert(value);
}

Object? _loggableResponseBody(Object? value) {
  if (value is String && value.length > 2000) {
    return '${value.substring(0, 2000)}...';
  }
  return value;
}

dynamic _toSerializable(dynamic value) {
  if (value is YamlMap) {
    return value.map((k, v) => MapEntry(k.toString(), _toSerializable(v)));
  } else if (value is YamlList) {
    return value.map(_toSerializable).toList();
  } else if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), _toSerializable(v)));
  } else if (value is List) {
    return value.map(_toSerializable).toList();
  }
  return value;
}
