import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/i18n_loader.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:brotli/brotli.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cryptography/cryptography.dart';

/// DefinitionProvider that reads the app manifest from CDN
class CdnDefinitionProvider extends DefinitionProvider {
  CdnDefinitionProvider(
    this.appId, {
    super.initialForcedLocale,
  });

  final String appId;

  final String baseUrl = 'https://cdn.ensembleui.com/manifests/apps';

  // Artifact caches
  final Map<String, dynamic> _artifactCache = {};
  final Map<String, String> _screenNameMappings = {};
  String? _homeMapping;
  String? _themeMapping;

  // Localization & config
  String? _defaultLocale;
  UserAppConfig? _appConfig;
  Map<String, String>? _secrets;

  // HTTP caching (ETag) + freshness
  String? _etag;
  int? _lastUpdatedAt;

  // Background update tracking
  bool _hasPendingUpdate = false;


  // Persistent cache key
  String get _artifactCacheKey => 'cdn_provider_state_$appId';

  static const String _i18nPrefix = 'i18n_';

  @override
  Future<DefinitionProvider> init() async {
    await _loadCachedState();
    if (_artifactCache.isNotEmpty) {
      unawaited(_refreshIfStale());
      return this;
    }

    await _loadManifest();
    return this;
  }

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    YamlMap? content;
    if (screenId != null) {
      final cached = _artifactCache[screenId];
      if (cached is YamlMap) content = cached;
    } else if (screenName != null) {
      final id = _screenNameMappings[screenName];
      final cached = id != null ? _artifactCache[id] : null;
      if (cached is YamlMap) content = cached;
    } else if (_homeMapping != null) {
      final cached = _artifactCache[_homeMapping];
      if (cached is YamlMap) content = cached;
    }
    return ScreenDefinition(content ?? YamlMap());
  }

  @override
  FlutterI18nDelegate? getI18NDelegate({Locale? forcedLocale}) {
    final defaultLoc = _localeFromString(_defaultLocale) ?? const Locale('en');
    return FlutterI18nDelegate(
      translationLoader: DataTranslationLoader(
        getTranslationMap: _getTranslationMap,
        defaultLocale: defaultLoc,
        forcedLocale: forcedLocale ?? initialForcedLocale,
      ),
    );
  }

  Map? _getTranslationMap(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    final country = locale.countryCode?.toUpperCase();
    if (country != null && country.isNotEmpty) {
      final fullKey = '$_i18nPrefix$lang-$country';
      final full = _artifactCache[fullKey];
      if (full is Map) return full;
    }
    final simple = _artifactCache['$_i18nPrefix$lang'];
    if (simple is Map) return simple;
    return null;
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    return AppBundle(
      theme: _themeMapping != null ? _artifactCache[_themeMapping] : null,
      resources: _artifactCache[ArtifactType.resources.name],
    );
  }

  @override
  UserAppConfig? getAppConfig() => _appConfig;

  @override
  Map<String, String> getSecrets() => _secrets ?? {};

  @override
  List<String> getSupportedLanguages() => _artifactCache.keys
      .where((k) => k.startsWith(_i18nPrefix))
      .map((k) => k.substring(_i18nPrefix.length))
      .toList();

  @override
  String? getHomeScreenName() {
    // Find the screen name that maps to the homeMapping ID
    if (_homeMapping != null) {
      return _screenNameMappings.entries
          .where((entry) => entry.value == _homeMapping)
          .map((entry) => entry.key)
          .firstOrNull;
    }
    return null;
  }

  @override
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // When app goes to background, fetch and update cache but DON'T fire events
      unawaited(_refreshIfStale());
    } else if (state == AppLifecycleState.resumed) {
      // When app comes to foreground, only fire events if enabled and we have pending updates
      if (isArtifactRefreshEnabled() && _hasPendingUpdate) {
        _fireManifestRefreshEvent();
        Ensemble().notifyAppBundleChanges();
        _hasPendingUpdate = false;
        if (kDebugMode) {
          debugPrint('✅ CDN Provider: Pending updates applied on resume');
        }
      }
    }
  }

  // --------------------------------------------------------
  // Persistent caching
  // --------------------------------------------------------

  Future<void> _loadCachedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached ETag and lastUpdatedAt
      final batched = prefs.getStringList(_artifactCacheKey);
      String? cachedManifest;
      if (batched != null && batched.length == 3) {
        _etag = batched[0];
        _lastUpdatedAt = int.tryParse(batched[1]);
        cachedManifest = batched[2];
      }

      if (cachedManifest != null && cachedManifest.isNotEmpty) {
        try {
          final root = jsonDecode(cachedManifest) as Map<String, dynamic>;
          _rebuildFromRoot(root);
        } catch (e) {
          // Clear invalid cache
          await _clearCache();
        }
      }
    } catch (e) {
      debugPrint('CdnProvider: Failed to load cached state: $e');
    }
  }

  Future<void> _saveCachedState(String manifestJson) async {
    // Fire-and-forget to avoid blocking UI
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final etagVal = _etag ?? '';
        final lastVal = (_lastUpdatedAt ?? 0).toString();
        await prefs
            .setStringList(_artifactCacheKey, [etagVal, lastVal, manifestJson]);
      } catch (e) {
        debugPrint('CdnProvider: Failed to save cached state: $e');
      }
    }());
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_artifactCacheKey);
    } catch (e) {
      debugPrint('CdnProvider: Failed to clear cache: $e');
    }
  }

  // --------------------------------------------------------
  // Networking / manifest loading
  // --------------------------------------------------------

  /// Check for updates and update cache if available
  /// Sets _hasPendingUpdate flag if updates were fetched
  Future<void> _refreshIfStale() async {
    try {
      final shouldFetch = await _shouldFetchManifest();
      if (!shouldFetch) {
        return;
      }

      final fetched = await _fetchManifest(ifNoneMatch: _etag);
      if (fetched == null) return;

      final jsonString = fetched['json'] as String?;
      if (jsonString == null) return;

      final newEtag = fetched['etag'] as String?;
      final root = jsonDecode(jsonString) as Map<String, dynamic>;

      _rebuildFromRoot(root);
      _etag = newEtag ?? _etag;

      // Save to persistent cache
      await _saveCachedState(jsonString);

      // Mark that we have updates
      _hasPendingUpdate = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ CDN Provider: Refresh failed: $e');
      }
    }
  }

  /// Fire a global refresh event to trigger UI updates across all screens
  /// CDN fetches the entire manifest atomically, so we can't determine which
  /// specific screens changed. Therefore, we fire a global refresh event that
  /// triggers all mounted screens to refresh.
  void _fireManifestRefreshEvent() {
    if (kDebugMode) {
      debugPrint('🔄 CDN Provider: Manifest updated - firing global refresh event');
    }

    // clear Ensemble's _parsedScriptCache (parsed JavaScript) as well
    Ensemble().getConfig()?.clearResourceCaches();
    AppEventBus().eventBus.fire(ResourceRefreshEvent(
      artifactId: 'cdn_manifest_$appId',
      artifactType: 'manifest',
    ));

    if (kDebugMode) {
      debugPrint('✅ CDN Provider: Global refresh event fired, all screens will update');
    }
  }

  Future<void> _loadManifest() async {
    final shouldFetch = await _shouldFetchManifest();
    if (!shouldFetch) {
      return;
    }

    final fetched = await _fetchManifest();
    if (fetched == null) return;

    final jsonString = fetched['json'] as String?;
    if (jsonString == null) return;

    _etag = fetched['etag'] as String?;

    final root = jsonDecode(jsonString) as Map<String, dynamic>;
    _rebuildFromRoot(root);

    // Save to persistent cache
    await _saveCachedState(jsonString);
  }

  Future<bool> _shouldFetchManifest() async {
    final lastUpdateUri = Uri.parse('$baseUrl/$appId/lastUpdateTime.json');

    try {
      final resp = await http.get(lastUpdateUri);
      if (resp.statusCode != 200) {
        return true;
      }

      final jsonString = _decodePossiblyBrotli(resp);
      if (jsonString == null || jsonString.isEmpty) {
        return true;
      }

      final lastUpdateData = jsonDecode(jsonString) as Map<String, dynamic>;
      final num? remoteLastUpdateNum = lastUpdateData['lastUpdatedAt'] as num?;
      final int? remoteLastUpdate = remoteLastUpdateNum?.toInt();

      if (remoteLastUpdate == null) {
        return true;
      }

      if (_lastUpdatedAt == null) {
        _lastUpdatedAt = remoteLastUpdate;
        return true;
      }

      final shouldFetch = _isIncomingNewer(remoteLastUpdate, _lastUpdatedAt);

      _lastUpdatedAt = remoteLastUpdate;

      return shouldFetch;
    } catch (e) {
      debugPrint(
          'CdnProvider: Error checking lastUpdateTime: $e, will fetch manifest');
      return true;
    }
  }

  Future<Map<String, Object>?> _fetchManifest({String? ifNoneMatch}) async {
    final uri = Uri.parse('$baseUrl/$appId/manifest.json');

    final headers = <String, String>{};
    if (ifNoneMatch != null && ifNoneMatch.isNotEmpty) {
      headers['If-None-Match'] = ifNoneMatch;
    }

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 304) return null;
    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw ConfigError(
          "Failed to fetch manifest from CDN. Please check your appId and make sure to sync app to CDN.");
    }

    final jsonString = _decodePossiblyBrotli(resp);
    if (jsonString == null || jsonString.isEmpty) return null;

    final etag = resp.headers['etag'] ?? resp.headers['ETag'];
    return {'json': jsonString, 'etag': etag ?? ''};
  }

  String? _decodePossiblyBrotli(http.Response resp) {
    final enc = (resp.headers['content-encoding'] ??
            resp.headers['Content-Encoding'] ??
            '')
        .toLowerCase();
    if (enc.contains('br') || enc.contains('brotli')) {
      try {
        final decompressed = brotliDecode(resp.bodyBytes);
        return utf8.decode(decompressed);
      } catch (_) {
        return resp.body;
      }
    }
    return resp.body;
  }

  // --------------------------------------------------------
  // Rebuild pipeline
  // --------------------------------------------------------

  void _rebuildFromRoot(Map<String, dynamic> root) {
    // reset caches/state
    _artifactCache.clear();
    _screenNameMappings.clear();
    _homeMapping = null;
    _themeMapping = null;
    _defaultLocale = null;
    _appConfig = null;
    _secrets = null;

    final artifacts = _asMap(root['artifacts']);
    if (artifacts == null) return;

    // 1) secrets
    final secretsPayload = _asMap(artifacts['secrets']);
    if (secretsPayload != null && secretsPayload.isNotEmpty) {
      decryptSecretsXChaCha(secretsPayload, appId: appId).then((decrypted) {
        _secrets = decrypted.map((k, v) => MapEntry(k, v.toString()));
      }).catchError((e) {
        debugPrint('Failed to decrypt secrets: $e');
        _secrets = {};
      });
    }

    // 2) config
    final configMap = _asMap(artifacts['config']);
    final String? baseUrl = configMap?['baseUrl']?.toString();
    bool? useBrowserUrl;
    if (configMap != null && configMap.containsKey('useBrowserUrl')) {
      final v = configMap['useBrowserUrl'];
      useBrowserUrl = v is bool ? v : v.toString().toLowerCase() == 'true';
    }

    Map<String, dynamic> envVars = Map<String, dynamic>.from(
        _asMap(configMap?['envVariables']) ?? const {});

    // 3) core artifacts
    _parseScreens(artifacts['screens']);
    _parseTheme(artifacts['theme']);
    _parseResources(artifacts['widgets'], artifacts['scripts']);
    _parseTranslations(artifacts['translations']);

    // 4) finalize AppConfig
    if (envVars.isNotEmpty || baseUrl != null || useBrowserUrl != null) {
      _appConfig = UserAppConfig(
        baseUrl: baseUrl,
        useBrowserUrl: useBrowserUrl,
        envVariables: envVars,
      );
    }
  }

  // --------------------------------------------------------
  // Parsers
  // --------------------------------------------------------
  void _parseScreens(dynamic screensRaw) {
    final screens = screensRaw is List ? screensRaw : const [];
    for (final entry in screens) {
      final screen = _asMap(entry);
      if (screen == null) continue;
      final id = screen['id']?.toString();
      final name = screen['name']?.toString();
      final bool isRoot = screen['isRoot'] == true;
      final content = screen['content']?.toString();
      if (id == null || content == null) continue;

      final yaml = _tryLoadYaml(content);
      _artifactCache[id] = yaml;
      if (name != null) _screenNameMappings[name] = id;
      if (isRoot && _homeMapping == null) _homeMapping = id;
    }
  }

  void _parseTheme(String themeRaw) {
    if (themeRaw.isNotEmpty) {
      final yaml = _tryLoadYaml(themeRaw);
      _artifactCache["theme"] = yaml;
      _themeMapping = "theme";
    }
  }

  void _parseResources(dynamic widgetsRaw, dynamic scriptsRaw) {
    final widgets = <String, dynamic>{};
    final code = <String, dynamic>{};

    if (widgetsRaw is Map) {
      widgetsRaw.forEach((k, v) {
        if (v is String && v.isNotEmpty) {
          final yaml = _tryLoadYaml(v);
          if (yaml != null) widgets[k] = yaml['Widget'] ?? yaml;
        }
      });
    } else if (widgetsRaw is List) {
      for (final item in widgetsRaw) {
        final w = _asMap(item);
        if (w == null) continue;
        final name = w['name']?.toString();
        final content = w['content']?.toString();
        if (name != null && content != null) {
          final yaml = _tryLoadYaml(content);
          if (yaml != null) widgets[name] = yaml['Widget'] ?? yaml;
        }
      }
    }

    if (scriptsRaw is Map) {
      scriptsRaw.forEach((k, v) {
        if (v is String) code[k] = v;
      });
    } else if (scriptsRaw is List) {
      for (final item in scriptsRaw) {
        final s = _asMap(item);
        if (s == null) continue;
        final name = s['name']?.toString();
        final content = s['content']?.toString();
        if (name != null && content != null) code[name] = content;
      }
    }

    final resources = {
      ResourceArtifactEntry.Widgets.name: widgets,
      ResourceArtifactEntry.Scripts.name: code,
    };
    if (resources.isNotEmpty) {
      _artifactCache[ArtifactType.resources.name] = YamlMap.wrap(resources);
    }
  }

  void _parseTranslations(dynamic translationsRaw) {
    if (translationsRaw is! List) return;

    for (final item in translationsRaw) {
      final t = _asMap(item);
      if (t == null) continue;
      final id = t['id']?.toString();
      String langCode = '';
      if (id != null && id.startsWith(_i18nPrefix)) {
        langCode = _normalizeLocale(id.substring(_i18nPrefix.length));
      }

      final yaml = _yamlFromUnknown(t['content']);
      final unwrapped = _unwrapI18nYaml(yaml);
      if (unwrapped != null)
        _artifactCache['$_i18nPrefix$langCode'] = unwrapped;

      if ((t['defaultLocale'] == true) && _defaultLocale == null) {
        _defaultLocale = langCode;
      }
    }
  }

  // --------------------------------------------------------
  // Helpers
  // --------------------------------------------------------

  static bool _isIncomingNewer(int? incoming, int? current) =>
      incoming != null && (current == null || incoming > current);

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static YamlMap? _tryLoadYaml(String content) {
    try {
      return loadYaml(content);
    } catch (_) {
      return null;
    }
  }

  static YamlMap? _yamlFromUnknown(dynamic content) {
    if (content is String && content.isNotEmpty) return _tryLoadYaml(content);
    if (content is Map) return YamlMap.wrap(content);
    return null;
  }

  static Map? _unwrapI18nYaml(YamlMap? yaml) {
    if (yaml == null) return null;
    if (yaml.length == 1) {
      final key = yaml.keys.first;
      if (key is String && key.startsWith(_i18nPrefix)) {
        final inner = yaml[key];
        if (inner is Map) return inner;
      }
    }
    return yaml;
  }

  static String _normalizeLocale(String code) {
    final trimmed = code.trim();
    if (trimmed.contains('_')) {
      final parts = trimmed.split('_');
      if (parts.length >= 2) {
        return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
      }
    }
    if (trimmed.contains('-')) {
      final parts = trimmed.split('-');
      if (parts.length >= 2) {
        return '${parts[0].toLowerCase()}-${parts[1].toUpperCase()}';
      }
    }
    return trimmed.toLowerCase();
  }

  static Locale? _localeFromString(String? code) {
    if (code == null || code.isEmpty) return null;
    final normalized = _normalizeLocale(code);
    if (normalized.contains('-')) {
      final parts = normalized.split('-');
      return Locale(parts[0], parts[1]);
    }
    return Locale(normalized);
  }

  Uint8List _b64Decode(String s) {
    var t = s.replaceAll('-', '+').replaceAll('_', '/');
    switch (t.length % 4) {
      case 2:
        t += '==';
        break;
      case 3:
        t += '=';
        break;
    }
    return Uint8List.fromList(base64.decode(t));
  }

  /// Decrypts the secrets payload
  Future<Map<String, dynamic>> decryptSecretsXChaCha(
    Map<String, dynamic> payload, {
    required String appId,
  }) async {
    if (payload.isEmpty) return {};

    // 1) Validate alg
    final alg = (payload['alg'] ?? '').toString().toUpperCase();
    if (alg != 'XCHACHA20-POLY1305') {
      throw StateError('Unsupported alg: $alg');
    }

    // 2) Load key
    final keyStr = 'gRet6enBqAoDobmL0x8G4Vdw7BE6NGMRKBF27Y1X7SU';
    final keyBytes = _b64Decode(keyStr);
    final secretKey = SecretKey(keyBytes);

    // 3) Decode nonce and data
    final nonce = _b64Decode(payload['nonce'] as String);
    final data = _b64Decode(payload['data'] as String);

    // 4) Split ciphertext and tag
    final tagLen = 16;
    final cipherText = Uint8List.sublistView(data, 0, data.length - tagLen);
    final tagBytes = Uint8List.sublistView(data, data.length - tagLen);

    // 5) AAD
    final aad = utf8.encode('appId:$appId');

    // 6) Decrypt
    final algo = Xchacha20.poly1305Aead();
    final clearBytes = await algo.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(tagBytes)),
      secretKey: secretKey,
      aad: aad,
    );

    final jsonStr = utf8.decode(clearBytes);
    return jsonDecode(jsonStr) as Map<String, dynamic>;
  }
}
