// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_cli_output.dart';
import 'package:ensemble_test_runner/cli/app_patcher.dart';
import 'package:ensemble_test_runner/cli/cli_compiled_plan_batch.dart';
import 'package:ensemble_test_runner/cli/cli_worker_batch_wire_transport.dart';
import 'package:ensemble_test_runner/execution/device_discovery.dart';
import 'package:path/path.dart' as p;

/// Builds the complete, deterministic command line passed to `flutter test`.
///
/// Keeping command construction separate from process orchestration makes the
/// worker boundary explicit and lets callers validate it without launching a
/// Flutter process.
List<String> buildFlutterTestArgs(
  List<String> arguments, {
  required String suiteEncryptionKey,
  required String? reportMode,
  required String? reportFile,
  required int? timeoutSeconds,
  required bool verbose,
  List<String> shardPaths = const [],
  List<String> shardIds = const [],
  int? workerIndex,
  String? progressFile,
  String? appLogPath,
  String? appLogDisplayPath,
  String? artifactRoot,
  Map<String, dynamic>? serviceOverrides,
  String artifactDisplayRoot = 'build/ensemble_test_runner',
  String testEntryRelativePath = TestAppPatcher.testEntryRelativePath,
  FlutterDevice? physicalDevice,
  bool hostOwnsServices = false,
  String? testsAssetPrefix,
  bool useRuntimeWorkerConfig = false,
}) {
  final planBatchFile = planBatchFileFromArguments(arguments);
  final runtimeWorkerConfig = useRuntimeWorkerConfig && physicalDevice == null;
  return [
    'test',
    testEntryRelativePath,
    '--no-pub',
    if (physicalDevice != null) ...['-d', physicalDevice.id],
    if (hostOwnsServices) '--dart-define=ensembleTestHostOwnsServices=true',
    if (testsAssetPrefix != null)
      '--dart-define=ensembleTestTestsAssetPrefix=${testsAssetPrefix.endsWith('/') ? testsAssetPrefix : '$testsAssetPrefix/'}',
    if (physicalDevice != null)
      '--dart-define=ensembleTestExecutionMode=integration',
    if (arguments.contains('--reset-device-storage'))
      '--dart-define=ensembleTestResetDeviceStorage=true',
    if (arguments.contains('--allow-device-storage-mutation'))
      '--dart-define=ensembleTestAllowDeviceStorageMutation=true',
    if (physicalDevice != null && !physicalDevice.isVirtual)
      '--dart-define=ensembleTestDeviceIsPhysical=true',
    if (!runtimeWorkerConfig)
      '--dart-define=ensembleTestEncryptionKey=$suiteEncryptionKey',
    if (physicalDevice != null) ...[
      '--dart-define=ensembleTestPhysicalDeviceId=${physicalDevice.id}',
      '--dart-define=ensembleTestPhysicalPlatform=${physicalDevice.platform}',
      '--dart-define=ensembleTestPhysicalDeviceName=${physicalDevice.name}',
    ],
    if (!runtimeWorkerConfig && reportMode != null)
      '--dart-define=ensembleTestReport=$reportMode',
    '--dart-define=ensembleTestEmitJsonReport=true',
    if (!runtimeWorkerConfig && reportFile != null)
      '--dart-define=ensembleTestReportFile=$reportFile',
    if (!runtimeWorkerConfig && timeoutSeconds != null)
      '--dart-define=ensembleTestTimeoutSeconds=$timeoutSeconds',
    if (!runtimeWorkerConfig && workerIndex != null) ...[
      '--dart-define=ensembleTestWorkerIndex=$workerIndex',
      '--dart-define=ensembleTestWorkerSuffix=worker${workerIndex + 1}',
    ],
    if (!runtimeWorkerConfig && progressFile != null)
      '--dart-define=ensembleTestProgressFile=$progressFile',
    if (!runtimeWorkerConfig && appLogPath != null)
      '--dart-define=ensembleTestAppLogFile=$appLogPath',
    if (!runtimeWorkerConfig && appLogDisplayPath != null)
      '--dart-define=ensembleTestAppLogDisplayFile=$appLogDisplayPath',
    if (!runtimeWorkerConfig && artifactRoot != null)
      '--dart-define=ensembleTestArtifactRoot=$artifactRoot',
    if (!runtimeWorkerConfig &&
        serviceOverrides != null &&
        serviceOverrides.isNotEmpty)
      '--dart-define=ensembleTestServiceOverrides=${json.encode(serviceOverrides)}',
    if (!runtimeWorkerConfig)
      '--dart-define=ensembleTestArtifactDisplayRoot=$artifactDisplayRoot',
    if (!runtimeWorkerConfig) ..._inputDartDefines(arguments),
    if (!runtimeWorkerConfig) ..._selectionDartDefines(arguments),
    if (!runtimeWorkerConfig && shardPaths.isNotEmpty)
      '--dart-define=ensembleTestShardPath=${shardPaths.join(',')}',
    if (!runtimeWorkerConfig && shardIds.isNotEmpty)
      '--dart-define=ensembleTestShardId=${shardIds.join(',')}',
    if (!runtimeWorkerConfig && planBatchFile != null)
      '--dart-define=ensembleTestPlanBatchFile=$planBatchFile',
    '--reporter',
    verbose ? 'expanded' : 'silent',
    ...flutterTestArguments(arguments),
  ];
}

/// Bounds Flutter's generated per-define kernel cache after a suite completes.
/// Keep recent entries warm while preventing unique test options from growing
/// the app's ignored build directory without limit.
void pruneFlutterTestKernelCache(
  Directory project, {
  // A single generated test kernel is typically around 120 MiB. Keeping one
  // warm kernel avoids recompiling the common path without allowing distinct
  // compile configurations to accumulate into multiple GiB.
  int maxBytes = 160 * 1024 * 1024,
}) {
  final cache = Directory(
    p.join(project.path, 'build', 'test_cache', 'build'),
  );
  if (!cache.existsSync()) return;

  final files = cache
      .listSync(followLinks: false)
      .whereType<File>()
      .where((file) =>
          file.path.endsWith('.cache.dill.track.dill') ||
          file.path.endsWith('.cache.dill'))
      .toList()
    ..sort((left, right) =>
        right.lastModifiedSync().compareTo(left.lastModifiedSync()));
  var retainedBytes = 0;
  for (final file in files) {
    final size = file.lengthSync();
    if (size <= maxBytes && retainedBytes + size <= maxBytes) {
      retainedBytes += size;
    } else {
      file.deleteSync();
    }
  }
}

/// Only the runner owns its package build cache. Host applications keep their
/// own Flutter build output; running a suite must not prune the host's cache.
bool isRunnerPackageRoot(Directory project) {
  final pubspec = File(p.join(project.path, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return false;
  return RegExp(r'^name:\s*ensemble_test_runner\s*$', multiLine: true)
      .hasMatch(pubspec.readAsStringSync());
}

Map<String, String> buildFlutterTestWorkerEnvironment({
  String? suiteEncryptionKey,
  String? artifactRoot,
  String artifactDisplayRoot = 'build/ensemble_test_runner',
  int? workerIndex,
  String? reportMode,
  int? timeoutSeconds,
  required List<String> shardPaths,
  required List<String> shardIds,
  required String? reportFile,
  required String? progressFile,
  required String? appLogPath,
  required String? appLogDisplayPath,
  required Map<String, dynamic>? serviceOverrides,
  required List<String> arguments,
}) {
  final planBatchFile = planBatchFileFromArguments(arguments);
  return {
    'ENSEMBLE_TEST_RUNNER_CONFIG': json.encode({
      if (suiteEncryptionKey != null)
        'ensembleTestEncryptionKey': suiteEncryptionKey,
      if (artifactRoot != null) 'ensembleTestArtifactRoot': artifactRoot,
      'ensembleTestArtifactDisplayRoot': artifactDisplayRoot,
      if (workerIndex != null) 'ensembleTestWorkerIndex': workerIndex,
      if (workerIndex != null)
        'ensembleTestWorkerSuffix': 'worker${workerIndex + 1}',
      'ensembleTestShardPath': shardPaths,
      'ensembleTestShardId': shardIds,
      if (reportFile != null) 'ensembleTestReportFile': reportFile,
      if (reportMode != null) 'ensembleTestReport': reportMode,
      if (timeoutSeconds != null) 'ensembleTestTimeoutSeconds': timeoutSeconds,
      if (progressFile != null) 'ensembleTestProgressFile': progressFile,
      if (appLogPath != null) 'ensembleTestAppLogFile': appLogPath,
      if (appLogDisplayPath != null)
        'ensembleTestAppLogDisplayFile': appLogDisplayPath,
      if (serviceOverrides != null && serviceOverrides.isNotEmpty)
        'ensembleTestServiceOverrides': json.encode(serviceOverrides),
      for (final selection in const [
        'id',
        'feature',
        'profile',
        'tag',
        'path',
        'device',
      ])
        if (_optionValues(arguments, '--$selection').isNotEmpty)
          'ensembleTest${selection[0].toUpperCase()}${selection.substring(1)}':
              _optionValues(arguments, '--$selection'),
      if (_inputValues(arguments).isNotEmpty)
        'ensembleTestInputs': json.encode(_inputValues(arguments)),
      if (planBatchFile != null) 'ensembleTestPlanBatchFile': planBatchFile,
    }),
  };
}

String? planBatchFileFromArguments(List<String> arguments) {
  final values = _optionValues(arguments, '--plan-batch-file');
  if (values.length > 1) {
    throw StateError('--plan-batch-file may be specified once.');
  }
  if (values.isEmpty) return null;
  return p.absolute(values.single);
}

void validatePlanBatchFile(List<String> arguments) {
  final path = planBatchFileFromArguments(arguments);
  if (path == null) return;
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Execution plan batch file not found: $path');
  }
  try {
    CliWorkerBatchWireTransport.decode(file.readAsStringSync());
  } on FormatException catch (error) {
    throw StateError('Invalid execution plan batch file "$path": $error');
  }
}

List<String> _selectionDartDefines(List<String> arguments) {
  final values = {
    'ensembleTestId': _optionValues(arguments, '--id'),
    'ensembleTestFeature': _optionValues(arguments, '--feature'),
    'ensembleTestProfile': _optionValues(arguments, '--profile'),
    'ensembleTestTag': _optionValues(arguments, '--tag'),
    'ensembleTestPath': _optionValues(arguments, '--path'),
    'ensembleTestDevice': _optionValues(arguments, '--device'),
  };
  return [
    for (final entry in values.entries)
      if (entry.value.isNotEmpty)
        '--dart-define=${entry.key}=${entry.value.join(',')}',
  ];
}

List<String> _inputDartDefines(List<String> arguments) {
  final inputs = _inputValues(arguments);
  if (inputs.isEmpty) return const [];
  final encoded = base64Url.encode(utf8.encode(jsonEncode(inputs)));
  return ['--dart-define=ensembleTestInputs=$encoded'];
}

Map<String, dynamic> _inputValues(List<String> arguments) {
  return inputValuesFromArguments(arguments);
}

List<String> _optionValues(List<String> arguments, String name) {
  return arguments
      .where((arg) => arg.startsWith('$name='))
      .map((arg) => arg.substring(name.length + 1))
      .where((value) => value.isNotEmpty)
      .toList();
}
