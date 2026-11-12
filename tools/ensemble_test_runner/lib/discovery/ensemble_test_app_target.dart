import 'package:ensemble/framework/ensemble_config_service.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Local app target resolved from `definitions.local` in
/// `ensemble/ensemble-config.yaml`.
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
      '${appPath.endsWith('/') ? appPath : '$appPath/'}tests/';
}

/// Reads the local definition target from the host app's Ensemble config.
Future<EnsembleTestAppTarget> loadEnsembleTestAppTarget() async {
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
      'Declarative tests require definitions.local in ensemble/ensemble-config.yaml '
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

  final i18n = local['i18n'];
  return EnsembleTestAppTarget(
    appPath: path.endsWith('/') ? path : '$path/',
    appHome: appHome,
    i18nPath: i18n is Map ? i18n['path']?.toString() : null,
  );
}
