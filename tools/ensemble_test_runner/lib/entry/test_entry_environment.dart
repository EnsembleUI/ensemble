// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
/// Shared environment and reporting boundary for test entry points.
///
/// Keeping dart-define decoding and machine report emission here ensures the
/// widget and application entry points interpret the same launch contract.
library;

import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:ensemble_test_runner/runner/test_artifacts.dart';
import 'package:ensemble_test_runner/entry/runner_runtime_configuration.dart';

String normalizedTestAssetPrefix(String value) {
  final normalized =
      value.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
  return normalized.endsWith('/') ? normalized : '$normalized/';
}

Map<String, dynamic> testInputsFromEnvironment() {
  final runtimeInputs =
      RunnerRuntimeConfiguration.current.string('ensembleTestInputs');
  if (runtimeInputs.isNotEmpty) {
    final decodedRuntime = json.decode(runtimeInputs);
    if (decodedRuntime is Map) {
      return decodedRuntime
          .map((key, value) => MapEntry(key.toString(), value));
    }
    throw EnsembleTestFailure('Invalid ensembleTestInputs runtime payload.');
  }
  const encoded = String.fromEnvironment('ensembleTestInputs');
  if (encoded.isEmpty) return const {};
  try {
    final value = json.decode(utf8.decode(base64Url.decode(encoded)));
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
  } catch (_) {
    // Fall through to the explicit failure below.
  }
  throw EnsembleTestFailure('Invalid ensembleTestInputs dart-define payload.');
}

EnsembleTestSelection testSelectionFromEnvironment() => EnsembleTestSelection(
      ids: RunnerRuntimeConfiguration.current.strings('ensembleTestId').toSet(),
      exactIds: RunnerRuntimeConfiguration.current
          .strings('ensembleTestShardId')
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet(),
      features: RunnerRuntimeConfiguration.current
          .strings('ensembleTestFeature')
          .toSet(),
      profiles: RunnerRuntimeConfiguration.current
          .strings('ensembleTestProfile')
          .toSet(),
      tags:
          RunnerRuntimeConfiguration.current.strings('ensembleTestTag').toSet(),
      paths: RunnerRuntimeConfiguration.current
          .strings('ensembleTestPath')
          .toSet(),
    );

/// Emits the machine-readable report using the launch environment contract.
void emitMachineTestReport(EnsembleTestRunResult result) {
  final reportMode =
      RunnerRuntimeConfiguration.current.string('ensembleTestReport');
  final reportFile =
      RunnerRuntimeConfiguration.current.string('ensembleTestReportFile');
  const emitJsonReport = bool.fromEnvironment('ensembleTestEmitJsonReport');
  // Most widget runs only use the normal boxed reporter. Keep the machine
  // encodings lazy so that an unused JSON or JUnit representation does not
  // allocate a second result tree on every attempt.
  String? encoded;
  String machineJson() => encoded ??= json.encode(result.toJson());
  String? junit;
  String junitXml() => junit ??= JunitTestReport.build(result);
  if (reportFile.isNotEmpty) {
    final file = File(reportFile);
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      reportMode == 'junit' ? junitXml() : machineJson(),
    );
  }
  if (usesDeviceArtifactTransport) {
    emitEnsembleTestMachineReport(machineJson());
  } else if (reportMode == 'json' || emitJsonReport) {
    print('ENSEMBLE_TEST_JSON_REPORT:${machineJson()}');
  }
  if (reportMode == 'junit') {
    print(
      'ENSEMBLE_TEST_JUNIT_REPORT:${junitXml().replaceAll('\n', r'\n')}',
    );
  }
}

/// Publishes a case-start event through the same progress transport used by
/// completion events. This keeps hosted and standalone entries observable by
/// the same CLI watcher while a case is still running.
void emitTestProgressStart(EnsembleTestDefinition definition) {
  final progressFile =
      RunnerRuntimeConfiguration.current.string('ensembleTestProgressFile');
  final event = json.encode(testProgressStartPayload(definition));
  if (progressFile.isEmpty) {
    if (usesDeviceArtifactTransport) {
      print('$ensembleTestProgressProtocolPrefix$event');
    }
    return;
  }
  final file = File(progressFile);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync('$event\n', mode: FileMode.append);
}

Map<String, dynamic> testProgressStartPayload(
  EnsembleTestDefinition definition, {
  DateTime? startedAt,
}) =>
    {
      'testId': definition.testCase.id,
      'assetPath': definition.assetPath,
      'status': 'running',
      'startedAtEpochMs': (startedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
