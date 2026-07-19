import 'dart:convert';

import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
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
          if (calls[i].mocked != null) 'mocked': calls[i].mocked,
          if (calls[i].statusCode != null) 'statusCode': calls[i].statusCode,
          if (calls[i].error != null) 'error': calls[i].error,
          if (calls[i].responseBody != null)
            'responseBody': _loggableResponseBody(calls[i].responseBody),
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
  );
}

Future<String> writeStorageLogFile({
  required TestLogger logger,
  required String filePrefix,
  String? key,
}) {
  if (key == null || key.isEmpty) {
    final storage = StorageManager();
    final entries = storage.getKeys().map(
          (key) => MapEntry(key, storage.read(key)),
        );
    return logger.writeLogFile(
      testId: filePrefix,
      name: 'storage',
      content: _prettyJson(Map<String, dynamic>.fromEntries(entries)),
      extension: 'json',
    );
  }

  return logger.writeLogFile(
    testId: filePrefix,
    name: 'storage_$key',
    content: _prettyJson(StorageManager().read(key)),
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
