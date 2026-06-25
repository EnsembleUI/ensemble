import 'package:ensemble/framework/dotenv_bundle.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class LocalAssetsService {
  static List<String> localAssets = [];
  static bool _isInitialized = false;

  /// Builds the env map used for local asset discovery.
  /// Values from `.env.assets` intentionally override app config values so
  /// local assets can replace remote URLs during local development.
  static Map<String, dynamic> mergeAssetEnvVariables(
    Map<String, dynamic>? envVariables,
    Iterable<Map<String, String>> envAssetSources,
  ) {
    final Map<String, dynamic> assetEnvVariables = {};
    if (envVariables != null) {
      assetEnvVariables.addAll(envVariables);
    }
    for (final source in envAssetSources) {
      assetEnvVariables.addAll(source);
    }
    return assetEnvVariables;
  }

  /// Scans configured asset environment values and records only the assets
  /// that are actually bundled with the app.
  static Future<void> initialize(
      Map<String, dynamic>? envVariables, YamlMap definations) async {
    final Map<String, String> envAssets = await _loadEnvAssets(definations);
    if (envVariables != null && envAssets.isNotEmpty) {
      envVariables.addAll(envAssets);
    }
    final Map<String, dynamic> assetEnvVariables = mergeAssetEnvVariables(
      envVariables,
      [envAssets],
    );

    List<String> foundAssets = [];
    if (assetEnvVariables.isNotEmpty) {
      for (var entry in assetEnvVariables.entries) {
        String assetName =
            Utils.getAssetName(entry.value); // Get the asset name
        String provider = definations['definitions']?['from'];
        String path = definations['definitions']?['local']['path'];
        String assetPath = provider == 'local'
            ? "$path/assets/$assetName"
            : "ensemble/assets/$assetName"; // Construct the full path

        bool exists = await _assetExists(assetPath); // Check if asset exists

        if (exists) {
          foundAssets.add(assetName); // Store only existing assets
        }
      }
    }

    localAssets = foundAssets;
    _isInitialized = true;
  }

  /// `.env.assets` is only supported for bundled local definitions
  static Future<Map<String, String>> _loadEnvAssets(YamlMap definations) async {
    try {
      String provider = definations['definitions']?['from'];
      if (provider != 'local') {
        return {};
      }
      String path = definations['definitions']?['local']['path'];
      if (path.endsWith('/')) {
        path = path.substring(0, path.length - 1);
      }
      final String assetPath = '$path/.env.assets';
      final String content = await rootBundle.loadString(assetPath);
      return parseDotEnvBundleContent(content);
    } catch (_) {
      return {};
    }
  }

  /// Returns whether a candidate asset path can be loaded from Flutter's bundle.
  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      return false; // Asset does not exist
    }
  }

  /// Used by startup code to avoid repeating bundle scans.
  static bool get isInitialized => _isInitialized;
}
