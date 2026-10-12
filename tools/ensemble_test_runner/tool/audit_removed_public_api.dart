import 'dart:io';

/// Audits that removed entry points and redundant result adapters stay out of the runtime.
void main() {
  final packageRoot = Directory.current;
  final lib = Directory('${packageRoot.path}/lib');
  if (!lib.existsSync()) {
    stderr.writeln('Run this audit from tools/ensemble_test_runner.');
    exitCode = 2;
    return;
  }

  const removedPublicSymbols = <String>[
    'EnsembleTestRunner.runOne',
    'registerEnsembleTests',
    'runEnsembleTestsWithOptions',
    'runEnsembleYamlTestsWithOptions',
    'runEnsembleYamlTests',
    'registerEnsembleYamlTests',
    'registerEnsembleYamlTestsInternal',
    'runEnsembleIntegrationYamlTests',
    'runApplicationYamlTests',
    'registerApplicationYamlTests',
    'runApplicationIntegrationYamlTests',
    'EnsembleYamlTestOptions',
    'YamlTestAppPatcher',
    'testEntryContents',
    'findTestYamlAssets',
    'findConfigYamlAsset',
    'writeScreenshotContactSheet',
    'observationElementsTreeForReport',
    'captureWaitForNavigationScreenshotForBenchmark',
    'buildIntegrationFlutterTestArgsForTest',
    'startListening',
    'onBeforeActionStep',
    'onAfterActionStep',
    'onBeforeActionOperation',
    'TestStep.canonicalType',
    'TestStep.withCanonicalType',
  ];
  const removedPublicPaths = <String>[
    'lib/runner/step_capture_guard.dart',
  ];

  final violations = <String>[];
  for (final path in removedPublicPaths) {
    if (File('${packageRoot.path}/$path').existsSync()) {
      violations.add('$path: removed forwarding facade');
    }
  }
  for (final entity in lib.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = _relative(packageRoot.path, entity.path);
    final source = entity.readAsStringSync();
    for (final name in removedPublicSymbols) {
      if (RegExp(r'\b' + RegExp.escape(name) + r'\b').hasMatch(source)) {
        violations.add('$relative: $name');
      }
    }
  }

  if (violations.isNotEmpty) {
    stderr.writeln('Removed public symbols found in the runtime:');
    for (final violation in violations..sort()) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }

  final resultProjection = File('${lib.path}/reporters/result_projection.dart');
  if (resultProjection.existsSync() &&
      RegExp(r'get\s+machineJson\b')
          .hasMatch(resultProjection.readAsStringSync())) {
    stderr.writeln(
      'TestResultProjection.machineJson must not duplicate result.toJson().',
    );
    exitCode = 1;
    return;
  }

  final stepExecutor = File('${lib.path}/actions/test_step_executor.dart');
  if (stepExecutor.existsSync()) {
    final source = stepExecutor.readAsStringSync();
    if (RegExp(r'\bFuture<void>\s+executeLifecycleOperation\s*\(')
        .hasMatch(source)) {
      stderr.writeln(
        'TestStepExecutor.executeLifecycleOperation must route through the '
        'validated lifecycle descriptor.',
      );
      exitCode = 1;
      return;
    }
    if (RegExp(r'\bFuture<void>\s+tapFinder\s*\(').hasMatch(source)) {
      stderr.writeln(
        'TestStepExecutor.tapFinder is an unused forwarding API; use the '
        'registered action route.',
      );
      exitCode = 1;
      return;
    }
  }

  final artifactLogs = File('${lib.path}/runner/debug_artifact_logs.dart');
  if (artifactLogs.existsSync()) {
    final source = artifactLogs.readAsStringSync();
    if (source.contains('Keep the legacy top-level fields') ||
        RegExp(r"final contentMap = <String, dynamic>\{\s*'keys':\s*snapshot")
            .hasMatch(source)) {
      stderr.writeln(
        'Storage artifacts must write the canonical nested storage section only.',
      );
      exitCode = 1;
      return;
    }
  }

  final reportDocument =
      File('${lib.path}/reporters/test_report_document.dart');
  if (reportDocument.existsSync()) {
    final source = reportDocument.readAsStringSync();
    if (source.contains("decoded['keys']") ||
        source.contains('Legacy flat storage snapshot')) {
      stderr.writeln(
        'Report storage decoding must not accept the retired flat snapshot format.',
      );
      exitCode = 1;
      return;
    }
  }

  final screenshotOptimizer =
      File('${lib.path}/runner/host_screenshot_optimizer.dart');
  if (screenshotOptimizer.existsSync()) {
    final source = screenshotOptimizer.readAsStringSync();
    if (source.contains("p.join(artifactRoot, 'screenshots')") ||
        source.contains('legacyManifestsDir')) {
      stderr.writeln(
        'Host screenshot optimization must read manifests only from frames/.',
      );
      exitCode = 1;
      return;
    }
  }

  final historyStore = File(
    '${packageRoot.path}/lib/reporters/ensemble_test_history_store.dart',
  );
  if (historyStore.existsSync()) {
    final source = historyStore.readAsStringSync();
    const retiredHistoryMarkers = <String>[
      'ensemble_test_history.db',
      '_movePreviousDatabase',
      '_copyLegacyHistory',
      '_needsMigration',
      'legacy_runs',
      'legacy_test_results',
      'legacy_failed_tests',
    ];
    final found = retiredHistoryMarkers
        .where((marker) => source.contains(marker))
        .toList(growable: false);
    if (found.isNotEmpty) {
      stderr.writeln(
        'Retired history database migration paths found: ${found.join(', ')}',
      );
      exitCode = 1;
      return;
    }
  }

  // Removed operations must stay absent from executable vocabulary and the
  // generated schema. Keep this separate from the naming boundary above:
  // these names have no supported compatibility alias and must never be
  // reintroduced by a registry or schema edit.
  const removedOperations = <String>[
    'setAuth',
    'clearAuth',
    'runScript',
    'expectScriptResult',
  ];
  final operationSources = <File>[];
  for (final root in [
    lib,
    Directory('${packageRoot.path}/assets/schema'),
  ]) {
    if (!root.existsSync()) continue;
    for (final entity in root.listSync(recursive: true)) {
      if (entity is File &&
          (entity.path.endsWith('.dart') || entity.path.endsWith('.json'))) {
        operationSources.add(entity);
      }
    }
  }
  final removedViolations = <String>[];
  for (final file in operationSources) {
    final relative = _relative(packageRoot.path, file.path);
    final source = file.readAsStringSync();
    for (final operation in removedOperations) {
      if (RegExp(r'\b' + RegExp.escape(operation) + r'\b').hasMatch(source)) {
        removedViolations.add('$relative: $operation');
      }
    }
  }
  if (removedViolations.isNotEmpty) {
    stderr.writeln('Removed executable operations found:');
    for (final violation in removedViolations..sort()) {
      stderr.writeln('  $violation');
    }
    exitCode = 1;
    return;
  }

  final resultModel = File('${lib.path}/models/test_results.dart');
  if (resultModel.existsSync()) {
    final source = resultModel.readAsStringSync();
    final factory = RegExp(
      r'factory\s+EnsembleSingleTestResult\.failed\s*\(\s*\{([\s\S]*?)\n\s*\}\)',
    ).firstMatch(source);
    if (factory != null &&
        RegExp(r'\bString\?\s+error\b').hasMatch(factory.group(1)!)) {
      stderr.writeln(
        'The failed-result constructor must use the canonical message field.',
      );
      exitCode = 1;
      return;
    }
  }
  stdout.writeln('Removed public symbols and operations remain absent.');
}

String _relative(String root, String path) {
  final prefix = root.endsWith(Platform.pathSeparator)
      ? root
      : '$root${Platform.pathSeparator}';
  return path.startsWith(prefix)
      ? path.substring(prefix.length).replaceAll(Platform.pathSeparator, '/')
      : path.replaceAll(Platform.pathSeparator, '/');
}
