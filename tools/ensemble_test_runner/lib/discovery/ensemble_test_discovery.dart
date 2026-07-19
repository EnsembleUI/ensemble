import 'dart:convert';

import 'package:ensemble/framework/ensemble_config_service.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_harness.dart';
import 'package:flutter/services.dart';

/// App target resolved from `ensemble/ensemble-config.yaml` (`definitions.local`).
class EnsembleTestAppTarget {
  final String appPath;
  final String appHome;
  final String? i18nPath;

  const EnsembleTestAppTarget({
    required this.appPath,
    required this.appHome,
    this.i18nPath,
  });

  String get testsAssetPrefix =>
      '${EnsembleTestHarness.normalizeAppPath(appPath)}tests/';
}

/// Discovers declarative tests and app settings from the host Flutter app bundle.
class EnsembleTestDiscovery {
  /// All `*.test.yaml` files bundled under [testsAssetPrefix].
  static Future<List<String>> findTestYamlAssets(
      String testsAssetPrefix) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final files = manifest
        .listAssets()
        .where(
          (path) =>
              path.startsWith(testsAssetPrefix) && path.endsWith('.test.yaml'),
        )
        .toList()
      ..sort();
    return files;
  }

  /// Optional suite-level config bundled as `tests/config.yaml`.
  static Future<String?> findConfigYamlAsset(String testsAssetPrefix) async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final path = '${testsAssetPrefix}config.yaml';
    return manifest.listAssets().contains(path) ? path : null;
  }

  static Future<EnsembleTestConfig> loadTestConfig(
    String testsAssetPrefix,
  ) async {
    final path = await findConfigYamlAsset(testsAssetPrefix);
    if (path == null) return const EnsembleTestConfig();
    final content = await rootBundle.loadString(path);
    final config = EnsembleTestParser.parseConfigString(
      content,
      sourcePath: path,
    );
    final overridden = _withServiceOverrides(config);
    if (overridden != null) return overridden;
    return _withWorkerIsolation(config);
  }

  static EnsembleTestConfig? _withServiceOverrides(EnsembleTestConfig config) {
    const rawOverrides = String.fromEnvironment('ensembleTestServiceOverrides');
    if (rawOverrides.isEmpty || config.services.isEmpty) return null;

    final dynamic decoded = json.decode(rawOverrides);
    if (decoded is! Map) return null;
    final overrides = Map<String, dynamic>.from(decoded);
    if (overrides.isEmpty) return null;

    return EnsembleTestConfig(
      services: [
        for (final service in config.services)
          _serviceWithOverride(
            service,
            overrides[service.name],
          ),
      ],
      mockFiles: config.mockFiles,
      inlineMocks: config.inlineMocks,
      initialState: config.initialState,
      devices: config.devices,
      screenshots: config.screenshots,
      performance: config.performance,
      timers: config.timers,
      dumpTree: config.dumpTree,
      logApiCalls: config.logApiCalls,
      logStorage: config.logStorage,
    );
  }

  static TestServiceConfig _serviceWithOverride(
    TestServiceConfig service,
    dynamic override,
  ) {
    if (override is! Map) return service;
    final map = Map<String, dynamic>.from(override);
    final url = map['url']?.toString();
    final environment = {
      ...service.environment,
      if (map['environment'] is Map)
        for (final entry in (map['environment'] as Map).entries)
          entry.key.toString(): entry.value.toString(),
    };
    return TestServiceConfig(
      name: service.name,
      command: service.command,
      url: url == null || url.isEmpty ? service.url : url,
      arguments: service.arguments,
      workingDirectory: service.workingDirectory,
      environment: environment,
      readyUrl: service.readyUrl,
      readyTimeoutMs: service.readyTimeoutMs,
    );
  }

  static EnsembleTestConfig _withWorkerIsolation(EnsembleTestConfig config) {
    const workerIndex = int.fromEnvironment(
      'ensembleTestWorkerIndex',
      defaultValue: 0,
    );
    if (workerIndex <= 0 || config.services.isEmpty) return config;

    return EnsembleTestConfig(
      services: [
        for (final service in config.services)
          TestServiceConfig(
            name: service.name,
            command: service.command,
            url: _offsetUrlPort(service.url, workerIndex),
            arguments: service.arguments,
            workingDirectory: service.workingDirectory,
            environment: {
              for (final entry in service.environment.entries)
                entry.key: entry.key == 'PORT'
                    ? _offsetPortString(entry.value, workerIndex)
                    : entry.value,
            },
            readyUrl: service.readyUrl,
            readyTimeoutMs: service.readyTimeoutMs,
          ),
      ],
      mockFiles: config.mockFiles,
      inlineMocks: config.inlineMocks,
      initialState: config.initialState,
      devices: config.devices,
      screenshots: config.screenshots,
      performance: config.performance,
      timers: config.timers,
      dumpTree: config.dumpTree,
      logApiCalls: config.logApiCalls,
      logStorage: config.logStorage,
    );
  }

  static String? _offsetUrlPort(String? value, int offset) {
    if (value == null || value.isEmpty) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasPort) return value;
    return uri.replace(port: uri.port + offset).toString();
  }

  static String _offsetPortString(String value, int offset) {
    final port = int.tryParse(value);
    return port == null ? value : '${port + offset}';
  }

  /// Reads `definitions.local` from `ensemble/ensemble-config.yaml`.
  static Future<EnsembleTestAppTarget> loadAppTarget() async {
    if (!EnsembleConfigService.isInitialized) {
      await EnsembleConfigService.initialize();
    }

    final definitions = EnsembleConfigService.config['definitions'];
    if (definitions is! Map) {
      throw EnsembleTestFailure(
        'ensemble/ensemble-config.yaml must define "definitions"',
      );
    }

    final local = definitions['local'];
    if (local is! Map) {
      throw EnsembleTestFailure(
        'Declarative tests require definitions.local in ensemble-config.yaml '
        '(path, appHome, i18n.path)',
      );
    }

    final path = local['path']?.toString();
    final appHome = local['appHome']?.toString();
    if (path == null || path.isEmpty || appHome == null || appHome.isEmpty) {
      throw EnsembleTestFailure(
        'definitions.local.path and definitions.local.appHome are required',
      );
    }

    String? i18nPath;
    final i18n = local['i18n'];
    if (i18n is Map && i18n['path'] != null) {
      i18nPath = i18n['path'].toString();
    }

    return EnsembleTestAppTarget(
      appPath: EnsembleTestHarness.normalizeAppPath(path),
      appHome: appHome,
      i18nPath: i18nPath,
    );
  }
}
