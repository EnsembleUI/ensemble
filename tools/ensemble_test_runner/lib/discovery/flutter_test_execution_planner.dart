import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:ensemble_test_runner/discovery/asset_string_loader.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_discovery.dart';
import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Flutter asset adapter for suite planning.
///
/// Filesystem tooling should call [EnsembleTestExecutionPlanner.buildForTest]
/// or [EnsembleTestExecutionPlanner.buildFromAssets] directly; those paths do
/// not depend on Flutter services.
abstract final class FlutterTestExecutionPlanner {
  static Future<EnsembleTestExecutionPlan> build({
    EnsembleTestAppTarget? target,
    String? testsAssetPrefix,
    EnsembleTestSelection selection = const EnsembleTestSelection(),
    Map<String, dynamic> inputs = const {},
  }) async {
    final resolvedTarget = testsAssetPrefix == null
        ? (target ?? await EnsembleTestDiscovery.loadAppTarget())
        : null;
    final resolvedPrefix = testsAssetPrefix ?? resolvedTarget!.testsAssetPrefix;
    final paths = await EnsembleTestDiscovery.findTestAssets(resolvedPrefix);
    final config = await EnsembleTestDiscovery.loadTestConfig(resolvedPrefix);
    if (paths.isEmpty) {
      throw EnsembleTestFailure(
        'No declarative tests found. Add *.test.yaml files under '
        '$resolvedPrefix',
      );
    }
    final assetContents = <String, String>{
      for (final path in paths) path: await rootBundle.loadString(path),
    };
    return EnsembleTestExecutionPlanner.buildFromAssets(
      assetContents: assetContents,
      config: config,
      selection: selection,
      inputs: inputs,
      assetLoader: _loadAsset,
    );
  }

  static Future<String> _loadAsset(String path) async {
    try {
      return await rootBundle.loadString(path);
    } on FlutterError catch (error) {
      throw AssetLoadException(path, error);
    }
  }
}
