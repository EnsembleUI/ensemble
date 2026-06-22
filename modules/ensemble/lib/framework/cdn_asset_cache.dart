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

class CdnAssetCache {
  CdnAssetCache({
    CdnAssetHttpGet? httpGet,
    CdnAssetStorageDirectoryProvider? storageDirectoryProvider,
  })  : _httpGet = httpGet ?? http.get,
        _storageDirectoryProvider =
            storageDirectoryProvider ?? _defaultStorageDirectoryProvider;

  static final CdnAssetCache instance = CdnAssetCache();

  final CdnAssetHttpGet _httpGet;
  final CdnAssetStorageDirectoryProvider _storageDirectoryProvider;
  final Map<String, Future<io.File?>> _inFlightDownloads = {};
  final Map<String, CdnAssetMetadata> _assets = {};
  final Map<String, CdnAssetCacheState> _cacheState = {};

  CdnAssetHeadersProvider _headersProvider = () async => const {};
  CdnAssetManifest? _assetManifest;
  String? _appId;
  String? _baseUrl;
  io.Directory? _rootDirectory;
  bool _initialized = false;
  bool _hasAssetManifest = false;

  bool get hasAssetManifest => _hasAssetManifest;
  int? get assetManifestUpdatedAt => _assetManifest?.updatedAt;

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
      await loadAssetManifest();
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to initialize: $e');
    }
  }

  bool isEligible(String source) {
    final fileName = _fileNameFromSource(source);
    return fileName != null && _assets.containsKey(fileName);
  }

  io.File? getCachedFileIfValid(String source) {
    if (kIsWeb || !_initialized || _rootDirectory == null) {
      return null;
    }
    final fileName = _fileNameFromSource(source);
    if (fileName == null) {
      return null;
    }
    final metadata = _assets[fileName];
    final state = _cacheState[fileName];
    if (metadata == null) {
      return null;
    }
    if (state == null) {
      return null;
    }
    if (state.hash != metadata.hash) {
      return null;
    }

    final file = _assetFile(fileName);
    try {
      if (file.existsSync()) {
        return file;
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  io.File? getCachedFileForBundleKey(String key) {
    if (kIsWeb || !_initialized || _rootDirectory == null) return null;
    final assetsPath = '${_assetsDirectory.path}${io.Platform.pathSeparator}';
    if (!key.startsWith(assetsPath)) return null;

    final fileName = key.substring(assetsPath.length);
    final cachedFile = getCachedFileIfValid(fileName);
    if (cachedFile?.path == key) {
      return cachedFile;
    }
    return null;
  }

  Future<io.File?> resolve(String source) {
    if (kIsWeb || !_initialized || _rootDirectory == null) {
      return Future.value(null);
    }
    final fileName = _fileNameFromSource(source);
    if (fileName == null || !_assets.containsKey(fileName)) {
      return Future.value(null);
    }

    final cached = getCachedFileIfValid(source);
    if (cached != null) {
      return Future.value(cached);
    }

    return _inFlightDownloads.putIfAbsent(
      fileName,
      () => _resolveFile(fileName).whenComplete(
        () {
          _inFlightDownloads.remove(fileName);
        },
      ),
    );
  }

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
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to load asset manifest: $e');
      _assets.clear();
      _cacheState.clear();
      _hasAssetManifest = false;
    }
  }

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
    await cleanupStaleAssets();
  }

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

  Future<void> cleanupStaleAssets() async {
    if (kIsWeb || _rootDirectory == null) return;
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
        _evictImageCache(fileName, file);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('CdnAssetCache: Failed to delete stale asset $fileName: $e');
      }
      _cacheState.remove(fileName);
    }

    await _writeCacheFile();
  }

  Future<io.File?> _resolveFile(String fileName) async {
    final metadata = _assets[fileName];
    if (metadata == null) {
      return null;
    }

    final validFile = await _validateCachedFile(fileName, metadata);
    if (validFile != null) {
      return validFile;
    }

    return _downloadAndStore(fileName, metadata);
  }

  Future<io.File?> _validateCachedFile(
    String fileName,
    CdnAssetMetadata metadata,
  ) async {
    final file = _assetFile(fileName);
    if (!await file.exists()) {
      return null;
    }

    try {
      final state = _cacheState[fileName];
      if (state != null && state.hash == metadata.hash) {
        return file;
      }

      _cacheState[fileName] = CdnAssetCacheState(
        hash: metadata.hash,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _writeCacheFile();
      return file;
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to validate asset $fileName: $e');
    }

    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
    _cacheState.remove(fileName);
    await _writeCacheFile();
    return null;
  }

  Future<io.File?> _downloadAndStore(
    String fileName,
    CdnAssetMetadata metadata,
  ) async {
    final appId = _appId;
    final baseUrl = _baseUrl;
    if (appId == null || baseUrl == null) {
      return null;
    }

    try {
      final headers = await _headersProvider();
      final uri = _assetUri(fileName, appId: appId, baseUrl: baseUrl);
      final response = await _httpGet(uri, headers: headers);
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        return null;
      }
      final bytes = response.bodyBytes;

      final file = _assetFile(fileName);
      await _writeFileAtomically(file, bytes);
      _cacheState[fileName] = CdnAssetCacheState(
        hash: metadata.hash,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await _writeCacheFile();
      return file;
    } catch (e) {
      debugPrint('CdnAssetCache: Failed to download asset $fileName: $e');
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
    await tempFile.writeAsBytes(bytes, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  void _replaceManifest(CdnAssetManifest manifest) {
    _assetManifest = manifest;
    _assets
      ..clear()
      ..addAll(manifest.assets);
  }

  String? _fileNameFromSource(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return null;

    String candidate;
    try {
      final uri = Uri.parse(trimmed);
      candidate = uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : uri.path.split('/').last;
    } catch (_) {
      candidate = trimmed.split('?').first.split('/').last;
    }

    try {
      candidate = Uri.decodeComponent(candidate);
    } catch (_) {}

    if (candidate.isEmpty ||
        candidate == '.' ||
        candidate == '..' ||
        candidate.contains('/') ||
        candidate.contains(r'\')) {
      return null;
    }
    return candidate;
  }

  io.File _assetFile(String fileName) =>
      io.File('${_assetsDirectory.path}/$fileName');

  Uri _assetUri(String fileName, {String? appId, String? baseUrl}) {
    final resolvedAppId = appId ?? _appId;
    final resolvedBaseUrl = baseUrl ?? _baseUrl;
    return Uri.parse(
      '$resolvedBaseUrl/$resolvedAppId/assets/${Uri.encodeComponent(fileName)}',
    );
  }

  void _evictImageCache(String fileName, io.File file) {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      unawaited(AssetImage(file.path).evict());

      final appId = _appId;
      final baseUrl = _baseUrl;
      if (appId != null && baseUrl != null) {
        unawaited(NetworkImage(_assetUri(fileName).toString()).evict());
      }
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
        final fileName = key.toString();
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
          final fileName = key.toString();
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
  });

  final String hash;
  final int size;
  final String? contentType;
  final int? updatedAt;

  static CdnAssetMetadata? fromJson(dynamic value) {
    if (value is! Map) return null;

    final hash = value['hash']?.toString().trim();
    final size = _intFromJson(value['size']);
    if (hash == null || hash.isEmpty || size == null || size < 0) {
      return null;
    }

    return CdnAssetMetadata(
      hash: hash,
      size: size,
      contentType: value['contentType']?.toString(),
      updatedAt: _intFromJson(value['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'size': size,
        if (contentType != null) 'contentType': contentType,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

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
  });

  /// Manifest hash used as the version/invalidation token.
  final String hash;
  final int downloadedAt;

  Map<String, dynamic> toJson() => {
        'downloadedAt': downloadedAt,
      };

  static CdnAssetCacheState? fromJson(dynamic value, {required String hash}) {
    if (value is! Map) return null;
    final downloadedAt = CdnAssetMetadata._intFromJson(value['downloadedAt']);
    if (downloadedAt == null) {
      return null;
    }
    return CdnAssetCacheState(
      hash: hash,
      downloadedAt: downloadedAt,
    );
  }
}
