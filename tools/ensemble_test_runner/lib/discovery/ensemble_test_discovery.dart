import 'package:ensemble/framework/ensemble_config_service.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
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
