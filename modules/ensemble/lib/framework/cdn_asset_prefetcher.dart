import 'package:ensemble/framework/cdn_asset_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:yaml/yaml.dart';

class CdnAssetPrefetcher {
  CdnAssetPrefetcher({CdnAssetCache? cache})
      : _cache = cache ?? CdnAssetCache.instance;

  static final CdnAssetPrefetcher instance = CdnAssetPrefetcher();

  static const int _maxScreens = 5;
  static const int _maxAssets = 10;
  static const int _maxBytes = 5 * 1024 * 1024;
  static const Duration _assetPrefetchDelay = Duration(milliseconds: 500);
  static const Duration _cacheIdleQuietPeriod = Duration(milliseconds: 500);
  static const Duration _idleTimeout = Duration(seconds: 2);

  final Map<String, int> _prefetchingScreens = {};
  final Set<String> _prefetchedScreens = {};
  final CdnAssetCache _cache;
  int? _prefetchManifestVersion;

  /// Starts prefetching assets for static navigation targets found in the
  /// current screen definition after foreground cache downloads settle.
  Future<void> prefetchNextScreenAssets(YamlMap currentScreen) async {
    await Future<void>.delayed(Duration.zero);
    if (kIsWeb || !_cache.hasAssetManifest) {
      return;
    }

    final manifestVersion = _cache.assetManifestUpdatedAt;
    if (manifestVersion == null) {
      return;
    }
    _resetIfManifestChanged(manifestVersion);

    final screenNames = _findStaticNextScreens(currentScreen)
        .take(_maxScreens)
        .toList(growable: false);
    if (screenNames.isEmpty) {
      return;
    }

    if (!await _waitUntilReadyToPrefetch(manifestVersion)) {
      return;
    }
    await _prefetchScreens(screenNames, manifestVersion);
  }

  /// Prefetches candidate screens in order while sharing the configured asset
  /// and byte budgets across the whole pass.
  Future<void> _prefetchScreens(
    List<String> screenNames,
    int manifestVersion,
  ) async {
    var prefetchedAssetCount = 0;
    var prefetchedBytes = 0;
    for (final screenName in screenNames) {
      if (!await _waitUntilReadyToPrefetch(manifestVersion)) return;
      final remainingAssets = _maxAssets - prefetchedAssetCount;
      final remainingBytes = _maxBytes - prefetchedBytes;
      if (remainingAssets <= 0 || remainingBytes <= 0) {
        return;
      }
      final result = await _prefetchScreenWithBudget(
        screenName,
        manifestVersion,
        maxAssets: remainingAssets,
        maxBytes: remainingBytes,
      );
      prefetchedAssetCount += result.assetCount;
      prefetchedBytes += result.bytes;
      if (result.budgetExhausted) return;
    }
  }

  /// Coordinates a single-screen prefetch and avoids repeating screens already
  /// completed or in progress for the active manifest.
  Future<_PrefetchScreenResult> _prefetchScreenWithBudget(
    String screenName,
    int manifestVersion, {
    required int maxAssets,
    required int maxBytes,
  }) async {
    if (!_isCurrentManifest(manifestVersion)) {
      return const _PrefetchScreenResult(success: false);
    }
    final activeVersion = _prefetchingScreens[screenName];
    if (_prefetchedScreens.contains(screenName) ||
        activeVersion == manifestVersion) {
      return const _PrefetchScreenResult(success: true);
    }

    _prefetchingScreens[screenName] = manifestVersion;
    try {
      final result = await _prefetchScreenAssets(
        screenName,
        manifestVersion,
        maxAssets: maxAssets,
        maxBytes: maxBytes,
      );
      if (_isCurrentManifest(manifestVersion) &&
          result.success &&
          !result.budgetExhausted) {
        _prefetchedScreens.add(screenName);
      }
      return result;
    } finally {
      if (_prefetchingScreens[screenName] == manifestVersion) {
        _prefetchingScreens.remove(screenName);
      }
    }
  }

  /// Downloads uncached screen assets at idle priority until the provided asset
  /// or byte budget is exhausted.
  Future<_PrefetchScreenResult> _prefetchScreenAssets(
    String screenName,
    int manifestVersion, {
    required int maxAssets,
    required int maxBytes,
  }) async {
    try {
      if (!await _waitUntilReadyToPrefetch(manifestVersion)) {
        return const _PrefetchScreenResult(success: false);
      }
      final assets = _cache.getPrefetchInfosForScreen(screenName);
      var prefetchedAssetCount = 0;
      var prefetchedBytes = 0;
      var hadDownloadFailure = false;
      var skippedDueToBudget = false;
      for (final asset in assets) {
        if (!await _waitUntilReadyToPrefetch(manifestVersion)) {
          return const _PrefetchScreenResult(success: false);
        }
        if (prefetchedAssetCount >= maxAssets || prefetchedBytes >= maxBytes) {
          return _PrefetchScreenResult(
            success: true,
            assetCount: prefetchedAssetCount,
            bytes: prefetchedBytes,
            budgetExhausted: true,
          );
        }
        if (_cache.getCachedFileIfValid(
              asset.fileName,
              updateLastUsed: false,
            ) !=
            null) {
          continue;
        }
        if (prefetchedBytes + asset.size > maxBytes) {
          skippedDueToBudget = true;
          continue;
        }
        await _waitForLowPrioritySlot();
        if (!await _waitUntilReadyToPrefetch(manifestVersion)) {
          return const _PrefetchScreenResult(success: false);
        }
        final file = await _cache.resolve(
          asset.fileName,
          updateLastUsed: false,
        );
        if (file != null) {
          prefetchedAssetCount += 1;
          prefetchedBytes += asset.size;
        } else {
          hadDownloadFailure = true;
        }
      }
      return _PrefetchScreenResult(
        success: !hadDownloadFailure,
        assetCount: prefetchedAssetCount,
        bytes: prefetchedBytes,
        budgetExhausted: skippedDueToBudget ||
            prefetchedAssetCount >= maxAssets ||
            prefetchedBytes >= maxBytes,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint('CDN asset prefetch failed for $screenName: $error');
      }
      return const _PrefetchScreenResult(success: false);
    }
  }

  /// Waits for an idle scheduler slot, with a timeout, before each prefetch
  /// download attempt.
  Future<void> _waitForLowPrioritySlot() async {
    await Future.any([
      SchedulerBinding.instance.scheduleTask<void>(
        () {},
        Priority.idle,
        debugLabel: 'CdnAssetPrefetcher.idle',
      ),
      Future<void>.delayed(_idleTimeout),
    ]);
    await Future<void>.delayed(_assetPrefetchDelay);
  }

  /// Clears in-memory prefetch tracking when a newer asset manifest is active.
  void _resetIfManifestChanged(int manifestVersion) {
    if (_prefetchManifestVersion == manifestVersion) return;
    _resetPrefetchState();
    _prefetchManifestVersion = manifestVersion;
  }

  void _resetPrefetchState() {
    _prefetchingScreens.clear();
    _prefetchedScreens.clear();
    _prefetchManifestVersion = null;
  }

  /// Returns whether the requested manifest version still matches the active
  /// cache manifest.
  bool _isCurrentManifest(int manifestVersion) =>
      _prefetchManifestVersion == manifestVersion &&
      _cache.assetManifestUpdatedAt == manifestVersion;

  /// Waits until cache downloads are quiet before allowing prefetch work to
  /// continue for the same manifest.
  Future<bool> _waitUntilReadyToPrefetch(int manifestVersion) async {
    if (!_isCurrentManifest(manifestVersion)) return false;

    while (_cache.hasActiveDownloads) {
      await _cache.waitForActiveDownloads();
      if (!_isCurrentManifest(manifestVersion)) return false;

      await Future<void>.delayed(_cacheIdleQuietPeriod);
      if (!_isCurrentManifest(manifestVersion)) return false;
    }

    return _isCurrentManifest(manifestVersion);
  }

  /// Finds literal screen names referenced by static navigate actions in a
  /// screen definition.
  Set<String> _findStaticNextScreens(dynamic value) {
    final screens = <String>{};
    _walk(value, (key, child) {
      if (key == 'navigateScreen' || key == 'navigateModalScreen') {
        final screenName =
            child is Map ? _staticString(child['name']) : _staticString(child);
        if (screenName != null) {
          screens.add(screenName);
        }
      }
    });
    return screens;
  }

  /// Recursively visits map entries inside a YAML-derived object graph.
  void _walk(
    dynamic value,
    void Function(String key, dynamic value) visitor,
  ) {
    if (value is Map) {
      value.forEach((key, child) {
        visitor(key.toString(), child);
        _walk(child, visitor);
      });
    } else if (value is Iterable) {
      for (final child in value) {
        _walk(child, visitor);
      }
    }
  }

  /// Returns a trimmed literal string, ignoring empty values and interpolated
  /// expressions that cannot be resolved statically.
  String? _staticString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.contains(r'${')) return null;
    return trimmed;
  }
}

class _PrefetchScreenResult {
  const _PrefetchScreenResult({
    required this.success,
    this.assetCount = 0,
    this.bytes = 0,
    this.budgetExhausted = false,
  });

  final bool success;
  final int assetCount;
  final int bytes;
  final bool budgetExhausted;
}
