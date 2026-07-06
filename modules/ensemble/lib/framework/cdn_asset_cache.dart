import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef CdnAssetHeadersProvider = Future<Map<String, String>> Function();
typedef CdnAssetHttpGet = Future<http.Response> Function(
  Uri uri, {
  Map<String, String>? headers,
});
typedef CdnAssetStorageDirectoryProvider = Future<io.Directory?> Function();

String? _normalizeCdnAssetKey(String key) {
  var candidate = key.trim();
  try {
    candidate = Uri.decodeComponent(candidate);
  } catch (_) {}

  if (candidate.isEmpty || candidate.contains(r'\')) {
    return null;
  }
  final segments = candidate.split('/');
  if (segments
      .any((segment) => segment.isEmpty || segment == '.' || segment == '..')) {
    return null;
  }
  return candidate;
}

class CdnAssetCache {
  CdnAssetCache({
    CdnAssetHttpGet? httpGet,
    CdnAssetStorageDirectoryProvider? storageDirectoryProvider,
  })  : _httpGet = httpGet ?? http.get,
        _storageDirectoryProvider =
            storageDirectoryProvider ?? _defaultStorageDirectoryProvider;

  static final CdnAssetCache instance = CdnAssetCache();
  static const Duration _assetExpiry = Duration(days: 30);
  static const Duration _lastUsedWriteInterval = Duration(days: 1);

  final CdnAssetHttpGet _httpGet;
  final CdnAssetStorageDirectoryProvider _storageDirectoryProvider;
  final Map<String, Future<io.File?>> _inFlightDownloads = {};
  final Map<String, CdnAssetMetadata> _assets = {};
  final Map<String, CdnAssetCacheState> _cacheState = {};
  Future<void>? _expiredAssetCleanupJob;

  CdnAssetHeadersProvider _headersProvider = () async => const {};
  CdnAssetManifest? _assetManifest;
  String? _appId;
  String? _baseUrl;
  io.Directory? _rootDirectory;
  bool _initialized = false;
  bool _hasAssetManifest = false;

  bool get hasAssetManifest => _hasAssetManifest;
  int? get assetManifestUpdatedAt => _assetManifest?.updatedAt;
  bool get hasActiveDownloads => _inFlightDownloads.isNotEmpty;

  /// Initializes the cache for a CDN app and loads any persisted manifest and
  /// cache state from disk.
  Future<void> initialize({
    required String appId,
    required String baseUrl,
    required CdnAssetHeadersProvider headersProvider,
  }) async {
    _appId = appId;
    _baseUrl = baseUrl;
    _headersProvider = headersProvider;
    _initialized = true;

    if (kIsWeb) return;

    try {
      final storageRoot = await _storageDirectoryProvider();
      if (storageRoot == null) {
        return;
      }
      _rootDirectory = io.Directory('${storageRoot.path}/asset_cache');
      await _assetsDirectory.create(recursive: true);
      await _deleteTempFilesFor(_cacheFile);
      await loadAssetManifest();
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to initialize: $e');
    }
  }

  /// Returns whether a source can be resolved from the active asset manifest.
  bool isEligible(String source) {
    final assetKey = _assetKeyFromSource(source);
    return assetKey != null && _assets.containsKey(assetKey);
  }

  /// Returns manifest asset names and sizes tagged for a screen, used by the
  /// prefetcher to decide what can be warmed ahead of navigation.
  List<({String fileName, int size})> getPrefetchInfosForScreen(
      String screenName) {
    final normalizedScreenName = screenName.trim();
    if (normalizedScreenName.isEmpty) {
      return const [];
    }

    final prefetchInfos = <({String fileName, int size})>[];
    for (final entry in _assets.entries) {
      final metadata = entry.value;
      if (!metadata.screens.contains(normalizedScreenName)) continue;
      prefetchInfos.add((fileName: entry.key, size: metadata.size));
    }
    return prefetchInfos;
  }

  /// Returns the cached file for a source only when the file exists and still
  /// matches the manifest hash, optionally recording it as user-visible usage.
  io.File? getCachedFileIfValid(
    String source, {
    bool updateLastUsed = true,
  }) {
    if (kIsWeb || !_initialized || _rootDirectory == null) {
      return null;
    }
    final assetKey = _assetKeyFromSource(source);
    if (assetKey == null) {
      return null;
    }
    final metadata = _assets[assetKey];
    final state = _cacheState[assetKey];
    if (metadata == null) {
      return null;
    }
    if (state == null) {
      return null;
    }
    if (state.hash != metadata.hash) {
      return null;
    }

    final file = _assetFile(assetKey);
    try {
      if (file.existsSync()) {
        if (updateLastUsed) {
          unawaited(_touchCachedAssetIfNeeded(assetKey, state));
        }
        return file;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Resolves an asset-bundle file path back to a valid cached CDN asset.
  io.File? getCachedFileForBundleKey(String key) {
    if (kIsWeb || !_initialized || _rootDirectory == null) return null;
    final assetsPath = '${_assetsDirectory.path}${io.Platform.pathSeparator}';
    if (!key.startsWith(assetsPath)) return null;

    final assetKey = key
        .substring(assetsPath.length)
        .replaceAll(io.Platform.pathSeparator, '/');
    final cachedFile = getCachedFileIfValid(assetKey);
    if (cachedFile?.path == key) {
      return cachedFile;
    }
    return null;
  }

  /// Returns a valid cached file for a source, or downloads and stores it using
  /// the active manifest metadata. Prefetch callers can skip usage tracking.
  Future<io.File?> resolve(
    String source, {
    bool updateLastUsed = true,
  }) {
    if (kIsWeb || !_initialized || _rootDirectory == null) {
      return Future.value(null);
    }
    final assetKey = _assetKeyFromSource(source);
    final metadata = assetKey != null ? _assets[assetKey] : null;
    if (assetKey == null || metadata == null) {
      return Future.value(null);
    }

    final cached = getCachedFileIfValid(
      source,
      updateLastUsed: updateLastUsed,
    );
    if (cached != null) {
      return Future.value(cached);
    }

    final inFlightKey = '$assetKey:${metadata.hash}';
    final existingDownload = _inFlightDownloads[inFlightKey];
    if (existingDownload != null) {
      if (!updateLastUsed) return existingDownload;
      return existingDownload.then((file) async {
        final state = _cacheState[assetKey];
        if (file != null && state != null) {
          await _touchCachedAssetIfNeeded(assetKey, state);
        }
        return file;
      });
    }

    final download = _resolveFile(
      assetKey,
      updateLastUsed: updateLastUsed,
    ).whenComplete(
      () {
        _inFlightDownloads.remove(inFlightKey);
      },
    );
    _inFlightDownloads[inFlightKey] = download;
    return download;
  }

  /// Waits until all currently active CDN asset downloads, including downloads
  /// that start while waiting, have completed.
  Future<void> waitForActiveDownloads() async {
    while (_inFlightDownloads.isNotEmpty) {
      final activeDownloads =
          List<Future<io.File?>>.from(_inFlightDownloads.values);
      await Future.wait(
        activeDownloads.map((download) => download.catchError((_) => null)),
      );
    }
  }

  /// Loads the persisted asset manifest and cache state into memory.
  Future<void> loadAssetManifest() async {
    if (kIsWeb || _rootDirectory == null) return;

    try {
      final cacheFile = await _loadCacheFile();
      _cacheState
        ..clear()
        ..addAll(cacheFile.cacheStates);
      final manifest = cacheFile.manifest;
      if (manifest == null) {
        _assets.clear();
        _hasAssetManifest = false;
        return;
      }
      _replaceManifest(manifest);
      _hasAssetManifest = true;
      await _validateCachedAssets();
      _scheduleExpiredAssetCleanup();
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to load asset manifest: $e');
      _assets.clear();
      _cacheState.clear();
      _hasAssetManifest = false;
    }
  }

  /// Saves a fetched asset manifest, removes stale cached assets, and refreshes
  /// any files whose manifest hash changed.
  Future<void> saveAssetManifest(String jsonString) async {
    if (kIsWeb || _rootDirectory == null) return;
    final manifest = CdnAssetManifest.fromJsonString(jsonString);
    final cacheFile = await _loadCacheFile();
    _cacheState
      ..clear()
      ..addAll(cacheFile.cacheStates);
    _replaceManifest(manifest);
    _hasAssetManifest = true;
    await _writeCacheFile();
    final staleAssetKeys = await cleanupStaleAssets();
    await _validateCachedAssets();
    await _downloadAssets(staleAssetKeys);
    _scheduleExpiredAssetCleanup();
  }

  /// Clears the active asset manifest and optionally removes all cached files.
  Future<void> clearAssetManifest({bool removeCachedAssets = false}) async {
    _assets.clear();
    _assetManifest = null;
    _hasAssetManifest = false;
    if (kIsWeb || _rootDirectory == null) return;

    try {
      if (removeCachedAssets) {
        _cacheState.clear();
        if (await _assetsDirectory.exists()) {
          await _assetsDirectory.delete(recursive: true);
        }
        await _assetsDirectory.create(recursive: true);
      }
      await _writeCacheFile();
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to clear asset manifest: $e');
    }
  }

  /// Removes cached files that are no longer present in the manifest or whose
  /// manifest hash no longer matches.
  Future<List<String>> cleanupStaleAssets() async {
    if (kIsWeb || _rootDirectory == null) return const [];
    final staleFileNames = _cacheState.entries
        .where((entry) {
          final metadata = _assets[entry.key];
          return metadata == null || metadata.hash != entry.value.hash;
        })
        .map((entry) => entry.key)
        .toList();

    for (final fileName in staleFileNames) {
      try {
        final file = _assetFile(fileName);
        await _evictImageCache(file);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('CdnAssetCache: Failed to delete stale asset $fileName: $e');
      }
      _cacheState.remove(fileName);
    }

    await _writeCacheFile();
    return staleFileNames;
  }

  /// Removes cached files that have not been used within the cache expiry
  /// window. Expired assets are downloaded again only if requested later.
  Future<List<String>> cleanupExpiredAssets() async {
    final activeCleanup = _expiredAssetCleanupJob;
    if (activeCleanup != null) {
      await activeCleanup;
      return const [];
    }
    return _cleanupExpiredAssets();
  }

  Future<List<String>> _cleanupExpiredAssets() async {
    if (kIsWeb || _rootDirectory == null) return const [];
    final expiresBefore =
        DateTime.now().subtract(_assetExpiry).millisecondsSinceEpoch;
    final expiredFileNames = _cacheState.entries
        .where((entry) =>
            (entry.value.lastUsedAt ?? entry.value.downloadedAt) <
            expiresBefore)
        .map((entry) => entry.key)
        .toList();

    for (final fileName in expiredFileNames) {
      try {
        final file = _assetFile(fileName);
        await _evictImageCache(file);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint(
            'CdnAssetCache: Failed to delete expired asset $fileName: $e');
      }
      _cacheState.remove(fileName);
    }

    if (expiredFileNames.isNotEmpty) {
      await _writeCacheFile();
    }
    return expiredFileNames;
  }

  void _scheduleExpiredAssetCleanup() {
    if (kIsWeb || _rootDirectory == null || _expiredAssetCleanupJob != null) {
      return;
    }
    final cleanupJob = Future<void>.delayed(Duration.zero).then((_) async {
      await _cleanupExpiredAssets();
    }).catchError((error) {
      debugPrint('CdnAssetCache: Failed to cleanup expired assets: $error');
    }).whenComplete(() {
      _expiredAssetCleanupJob = null;
    });
    _expiredAssetCleanupJob = cleanupJob;
    unawaited(cleanupJob);
  }

  Future<void> _downloadAssets(List<String> assetKeys) async {
    for (final assetKey in assetKeys) {
      await resolve(assetKey, updateLastUsed: false);
    }
  }

  Future<void> _validateCachedAssets() async {
    if (kIsWeb || _rootDirectory == null) return;
    var changed = false;
    final cachedAssetKeys = _cacheState.keys.toList();
    for (final assetKey in cachedAssetKeys) {
      final metadata = _assets[assetKey];
      if (metadata == null) {
        _cacheState.remove(assetKey);
        changed = true;
        continue;
      }
      final validFile = await _validateCachedFile(
        assetKey,
        metadata,
        writeCacheFile: false,
      );
      if (validFile == null) {
        changed = true;
      }
    }
    if (changed) {
      await _writeCacheFile();
    }
  }

  Future<io.File?> _resolveFile(
    String assetKey, {
    required bool updateLastUsed,
  }) async {
    final metadata = _assets[assetKey];
    if (metadata == null) {
      return null;
    }

    final validFile = await _validateCachedFile(assetKey, metadata);
    if (validFile != null) {
      return validFile;
    }

    return _downloadAndStore(
      assetKey,
      metadata,
      updateLastUsed: updateLastUsed,
    );
  }

  Future<io.File?> _validateCachedFile(
    String assetKey,
    CdnAssetMetadata metadata, {
    bool writeCacheFile = true,
  }) async {
    final file = _assetFile(assetKey);
    if (!await file.exists()) {
      return null;
    }

    try {
      final state = _cacheState[assetKey];
      if (state != null && state.hash == metadata.hash) {
        return file;
      }
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to validate asset $assetKey: $e');
    }

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    _cacheState.remove(assetKey);
    if (writeCacheFile) {
      await _writeCacheFile();
    }
    return null;
  }

  Future<io.File?> _downloadAndStore(
    String assetKey,
    CdnAssetMetadata metadata, {
    required bool updateLastUsed,
  }) async {
    final appId = _appId;
    final baseUrl = _baseUrl;
    if (appId == null || baseUrl == null) {
      return null;
    }

    try {
      final headers = await _headersProvider();
      final uri = _assetUri(assetKey, appId: appId, baseUrl: baseUrl);
      final response = await _httpGet(uri, headers: headers);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final bytes = response.bodyBytes;

      final file = _assetFile(assetKey);
      await _writeFileAtomically(file, bytes);
      final now = DateTime.now().millisecondsSinceEpoch;
      _cacheState[assetKey] = CdnAssetCacheState(
        hash: metadata.hash,
        downloadedAt: now,
        lastUsedAt: updateLastUsed ? now : null,
      );
      await _writeCacheFile();
      return file;
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to download asset $assetKey: $e');
      return null;
    }
  }

  Future<CdnAssetCacheFile> _loadCacheFile() async {
    if (_rootDirectory == null) return const CdnAssetCacheFile();
    final file = _cacheFile;
    if (await file.exists()) {
      return CdnAssetCacheFile.fromJsonString(await file.readAsString());
    }

    return const CdnAssetCacheFile();
  }

  Future<void> _writeCacheFile() async {
    if (_rootDirectory == null) return;
    final cacheFile = CdnAssetCacheFile(
      manifest: _hasAssetManifest ? _assetManifest : null,
      cacheStates: Map.of(_cacheState),
    );
    await _writeFileAtomically(
      _cacheFile,
      utf8.encode(jsonEncode(cacheFile.toJson())),
    );
  }

  Future<void> _writeFileAtomically(io.File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final tempFile = io.File(
      '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    try {
      await tempFile.writeAsBytes(bytes, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  Future<void> _deleteTempFilesFor(io.File file) async {
    final parent = file.parent;
    if (!await parent.exists()) return;
    final prefix = '${file.uri.pathSegments.last}.tmp-';
    await for (final entity in parent.list()) {
      if (entity is io.File &&
          entity.uri.pathSegments.last.startsWith(prefix)) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  Future<void> _touchCachedAssetIfNeeded(
    String assetKey,
    CdnAssetCacheState state,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final lastUsedAt = state.lastUsedAt;
    final lastUsedAge = lastUsedAt != null
        ? Duration(milliseconds: now - lastUsedAt)
        : _lastUsedWriteInterval;
    if (lastUsedAge < _lastUsedWriteInterval) return;

    _cacheState[assetKey] = state.copyWith(lastUsedAt: now);
    await _writeCacheFile().catchError((error) {
      debugPrint(
          'CdnAssetCache: Failed to update last used for $assetKey: $error');
    });
  }

  void _replaceManifest(CdnAssetManifest manifest) {
    _assetManifest = manifest;
    _assets
      ..clear()
      ..addAll(manifest.assets);
  }

  String? _assetKeyFromSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.hasScheme) {
      if (uri.scheme != 'http' && uri.scheme != 'https') {
        return null;
      }
      return _assetKeyFromManagedUri(uri);
    }

    return _normalizeCdnAssetKey(trimmed.split('?').first.split('#').first);
  }

  String? _assetKeyFromManagedUri(Uri uri) {
    final appId = _appId;
    final baseUrl = _baseUrl;
    if (appId == null || baseUrl == null) return null;

    final baseUri = Uri.tryParse('$baseUrl/$appId/assets/');
    if (baseUri == null ||
        uri.scheme != baseUri.scheme ||
        uri.host != baseUri.host ||
        uri.port != baseUri.port) {
      return null;
    }

    final baseSegments =
        baseUri.pathSegments.where((s) => s.isNotEmpty).toList();
    final uriSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (uriSegments.length <= baseSegments.length) return null;
    for (var i = 0; i < baseSegments.length; i++) {
      if (uriSegments[i] != baseSegments[i]) return null;
    }
    return _normalizeCdnAssetKey(
        uriSegments.skip(baseSegments.length).join('/'));
  }

  io.File _assetFile(String assetKey) =>
      io.File('${_assetsDirectory.path}/$assetKey');

  Uri _assetUri(String assetKey, {String? appId, String? baseUrl}) {
    final resolvedAppId = appId ?? _appId;
    final resolvedBaseUrl = baseUrl ?? _baseUrl;
    final encodedPath = assetKey.split('/').map(Uri.encodeComponent).join('/');
    return Uri.parse('$resolvedBaseUrl/$resolvedAppId/assets/$encodedPath');
  }

  Future<void> _evictImageCache(io.File file) async {
    try {
      await AssetImage(file.path).evict();
      await FileImage(file).evict();
    } catch (_) {}
  }

  io.File get _cacheFile => io.File('${_rootDirectory!.path}/asset-cache.json');

  io.Directory get _assetsDirectory =>
      io.Directory('${_rootDirectory!.path}/assets');

  static Future<io.Directory?> _defaultStorageDirectoryProvider() async {
    if (kIsWeb) return null;
    return getApplicationSupportDirectory();
  }
}

class CdnAssetManifest {
  const CdnAssetManifest({
    required this.assets,
    this.updatedAt,
  });

  final int? updatedAt;
  final Map<String, CdnAssetMetadata> assets;

  factory CdnAssetManifest.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    return CdnAssetManifest.fromJson(decoded);
  }

  factory CdnAssetManifest.fromJson(dynamic decoded) {
    if (decoded is! Map) {
      throw const FormatException('Asset manifest root is not a JSON object.');
    }

    final rawAssets = decoded['assets'];
    final assets = <String, CdnAssetMetadata>{};
    if (rawAssets is Map) {
      rawAssets.forEach((key, value) {
        final fileName = _normalizeCdnAssetKey(key.toString());
        if (fileName == null) return;
        final metadata = CdnAssetMetadata.fromJson(value);
        if (metadata != null) {
          assets[fileName] = metadata;
        }
      });
    }

    return CdnAssetManifest(
      updatedAt: CdnAssetMetadata._intFromJson(decoded['updatedAt']),
      assets: assets,
    );
  }

  Map<String, dynamic> toJson() => {
        if (updatedAt != null) 'updatedAt': updatedAt,
        'assets': assets.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };
}

class CdnAssetCacheFile {
  const CdnAssetCacheFile({
    this.manifest,
    this.cacheStates = const {},
  });

  final CdnAssetManifest? manifest;
  final Map<String, CdnAssetCacheState> cacheStates;

  factory CdnAssetCacheFile.fromJsonString(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('Asset cache root is not a JSON object.');
    }

    final manifest = CdnAssetManifest.fromJson(decoded);
    final cacheStates = <String, CdnAssetCacheState>{};
    final rawAssets = decoded['assets'];
    if (rawAssets is Map) {
      rawAssets.forEach((key, value) {
        if (value is Map) {
          final fileName = _normalizeCdnAssetKey(key.toString());
          if (fileName == null) return;
          final metadata = manifest.assets[fileName];
          if (metadata == null) return;
          final cacheState = CdnAssetCacheState.fromJson(
            value['cache'],
            hash: metadata.hash,
          );
          if (cacheState != null) {
            cacheStates[fileName] = cacheState;
          }
        }
      });
    }

    return CdnAssetCacheFile(
      manifest: manifest.assets.isEmpty ? null : manifest,
      cacheStates: cacheStates,
    );
  }

  Map<String, dynamic> toJson() {
    final json = manifest?.toJson() ?? <String, dynamic>{'assets': {}};
    final assets = json['assets'];
    if (assets is Map) {
      cacheStates.forEach((key, value) {
        final asset = assets[key];
        if (asset is Map) {
          asset['cache'] = value.toJson();
        }
      });
    }
    return json;
  }
}

class EnsembleAssetBundle extends CachingAssetBundle {
  EnsembleAssetBundle({required this.parent});

  final AssetBundle parent;

  @override
  Future<ByteData> load(String key) async {
    final cachedFile = CdnAssetCache.instance.getCachedFileForBundleKey(key);
    if (cachedFile != null) {
      final bytes = await cachedFile.readAsBytes();
      final data = Uint8List.fromList(bytes);
      return ByteData.view(data.buffer);
    }
    return parent.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    final cachedFile = CdnAssetCache.instance.getCachedFileForBundleKey(key);
    if (cachedFile != null) {
      return utf8.decode(await cachedFile.readAsBytes());
    }
    return parent.loadString(key, cache: cache);
  }
}

class CdnAssetMetadata {
  const CdnAssetMetadata({
    required this.hash,
    required this.size,
    this.contentType,
    this.updatedAt,
    this.screens = const [],
  });

  final String hash;
  final int size;
  final String? contentType;
  final int? updatedAt;
  final List<String> screens;
  static final RegExp _sha256Pattern = RegExp(r'^[a-f0-9]{64}$');

  static CdnAssetMetadata? fromJson(dynamic value) {
    if (value is! Map) return null;

    final hash = value['hash']?.toString().trim().toLowerCase();
    final size = _intFromJson(value['size']);
    if (hash == null ||
        !_sha256Pattern.hasMatch(hash) ||
        size == null ||
        size < 0) {
      return null;
    }

    return CdnAssetMetadata(
      hash: hash,
      size: size,
      contentType: value['contentType']?.toString(),
      updatedAt: _intFromJson(value['updatedAt']),
      screens: _screensFromJson(value['screens']),
    );
  }

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'size': size,
        if (contentType != null) 'contentType': contentType,
        if (updatedAt != null) 'updatedAt': updatedAt,
        'screens': screens,
      };

  static List<String> _screensFromJson(dynamic value) {
    if (value is! Iterable) return const [];
    return value
        .map((screen) => screen?.toString().trim())
        .whereType<String>()
        .where((screen) => screen.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static int? _intFromJson(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }
}

class CdnAssetCacheState {
  const CdnAssetCacheState({
    required this.hash,
    required this.downloadedAt,
    required this.lastUsedAt,
  });

  /// Manifest hash used as the version/invalidation token.
  final String hash;
  final int downloadedAt;

  /// Last time the asset was actually used. Null means it has only been cached,
  /// for example by prefetch.
  final int? lastUsedAt;

  Map<String, dynamic> toJson() => {
        'downloadedAt': downloadedAt,
        'lastUsedAt': lastUsedAt,
      };

  CdnAssetCacheState copyWith({
    int? downloadedAt,
    int? lastUsedAt,
  }) =>
      CdnAssetCacheState(
        hash: hash,
        downloadedAt: downloadedAt ?? this.downloadedAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      );

  static CdnAssetCacheState? fromJson(dynamic value, {required String hash}) {
    if (value is! Map) return null;
    final downloadedAt = CdnAssetMetadata._intFromJson(value['downloadedAt']);
    if (downloadedAt == null) {
      return null;
    }
    final resolvedLastUsedAt = value.containsKey('lastUsedAt')
        ? CdnAssetMetadata._intFromJson(value['lastUsedAt'])
        : downloadedAt;
    return CdnAssetCacheState(
      hash: hash,
      downloadedAt: downloadedAt,
      lastUsedAt: resolvedLastUsedAt,
    );
  }
}
