import 'dart:async';

import 'package:ensemble/util/utils.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

class LocalAssetsService {
  static List<String> localAssets = [];
  static bool _isInitialized = false;

  static Future<void> initialize(
      Map<String, dynamic>? envVariables, YamlMap definations) async {
    List<String> foundAssets = [];
    if (envVariables != null) {
      for (var entry in envVariables.entries) {
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

enum AssetSourceType { asset, cdn, remote }

class AssetResolution {
  AssetResolution._(this.path, this.type, {required this.originalSource});

  factory AssetResolution.asset(String path,
          {required String originalSource}) =>
      AssetResolution._(path, AssetSourceType.asset,
          originalSource: originalSource);

  factory AssetResolution.cdn(String path, {required String originalSource}) =>
      AssetResolution._(path, AssetSourceType.cdn,
          originalSource: originalSource);

  factory AssetResolution.remote(String path,
          {required String originalSource}) =>
      AssetResolution._(path, AssetSourceType.remote,
          originalSource: originalSource);

  final String path;
  final AssetSourceType type;
  final String originalSource;

  bool get isAsset => type == AssetSourceType.asset;
  bool get isRemote => type != AssetSourceType.asset;
}

class AssetResolver {
  static final Map<String, Future<AssetResolution>> _inFlight = {};

  static Future<AssetResolution> resolve(String source) {
    if (!Utils.isUrl(source)) {
      return Future.value(
        AssetResolution.asset(Utils.getLocalAssetFullPath(source),
            originalSource: source),
      );
    }

    final assetName = Utils.getAssetName(source);
    if (assetName.isNotEmpty && Utils.isAssetAvailableLocally(assetName)) {
      return Future.value(
        AssetResolution.asset(Utils.getLocalAssetFullPath(assetName),
            originalSource: source),
      );
    }

    final cacheKey = '$source::$assetName';
    if (_inFlight.containsKey(cacheKey)) {
      return _inFlight[cacheKey]!;
    }
    final future = _resolveRemote(source, assetName);
    _inFlight[cacheKey] = future;
    future.whenComplete(() => _inFlight.remove(cacheKey));
    return future;
  }

  static Future<AssetResolution> _resolveRemote(
      String originalSource, String assetName) async {
    if (assetName.isEmpty) {
      return AssetResolution.remote(originalSource,
          originalSource: originalSource);
    }

    final cdnUrl = await CdnAssetsService.getAssetUrlIfAvailable(assetName);
    if (cdnUrl != null) {
      return AssetResolution.cdn(cdnUrl, originalSource: originalSource);
    }

    return AssetResolution.remote(originalSource,
        originalSource: originalSource);
  }
}

class CdnAssetsService {
  static String? _appId;
  static String baseUrl = 'https://cdn.ensembleui.com/manifests/apps';
  static final Map<String, bool> _availabilityCache = {};
  static final Map<String, Future<bool>> _pendingChecks = {};

  static void updateAppId(String? appId) {
    if (appId == null || appId == _appId) {
      return;
    }
    _appId = appId;
    _availabilityCache.clear();
    _pendingChecks.clear();
  }

  static String? getCachedAssetUrl(String assetName) {
    if (_appId == null || assetName.isEmpty) {
      return null;
    }
    if (_availabilityCache[assetName] == true) {
      return _buildAssetUrl(assetName);
    }
    return null;
  }

  static Future<String?> getAssetUrlIfAvailable(String assetName) async {
    if (_appId == null || assetName.isEmpty) {
      return null;
    }
    if (_availabilityCache.containsKey(assetName)) {
      return _availabilityCache[assetName]! ? _buildAssetUrl(assetName) : null;
    }

    final future = _pendingChecks[assetName] ??= _probeAsset(assetName);
    final available = await future;
    _availabilityCache[assetName] = available;
    _pendingChecks.remove(assetName);
    return available ? _buildAssetUrl(assetName) : null;
  }

  static Future<bool> _probeAsset(String assetName) async {
    final url = _buildAssetUrl(assetName);
    try {
      final response = await http.head(Uri.parse(url));
      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 202 ||
          response.statusCode == 204) {
        return true;
      }
      if (response.statusCode == 403 || response.statusCode == 401) {
        return true;
      }
      // Some CDNs disallow HEAD and return 405. Attempt a lightweight GET.
      if (response.statusCode == 405) {
        final getResponse =
            await http.get(Uri.parse(url), headers: {'Range': 'bytes=0-0'});
        return getResponse.statusCode == 200 || getResponse.statusCode == 206;
      }
    } catch (_) {
      // swallow and treat as unavailable
    }
    return false;
  }

  static String _buildAssetUrl(String assetName) {
    final safeName = Uri.encodeComponent(assetName);
    return '$baseUrl/${_appId!}/assets/$safeName';
  }
}
