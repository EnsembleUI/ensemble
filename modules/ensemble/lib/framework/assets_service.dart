import 'package:ensemble/util/utils.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

class LocalAssetsService {
  static List<String> localAssets = [];
  static bool _isInitialized = false;

  static Future<void> initialize(
      Map<String, dynamic>? envVariables, YamlMap definations) async {
    List<String> foundAssets = [];

    for (var entry in envVariables!.entries) {
      String assetName = Utils.getAssetName(entry.value); // Get the asset name
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

    localAssets = foundAssets;
    _isInitialized = true;
  }

  static Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (e) {
      return false; // Asset does not exist
    }
  }

  static bool get isInitialized => _isInitialized;
}
