import 'dart:async';
import 'dart:convert';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/i18n_loader.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:brotli/brotli.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// DefinitionProvider that reads a pre-built app manifest from Storage bucket
class CdnDefinitionProvider extends DefinitionProvider {
  CdnDefinitionProvider(
    this.appId, {
    super.initialForcedLocale,
  });

  final String appId;

  final String baseUrl = 'https://cdn.ensembleui.com/manifests/apps';

  String get _lastUpdateTimeUrl {
    return '$baseUrl/$appId/lastUpdateTime.json';
  }

  String get _manifestUrl {
    return '$baseUrl/$appId/manifest.json';
  }

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

  // Persistent cache keys
  String get _etagKey => 'cdn_provider_etag_$appId';
  String get _lastUpdatedAtKey => 'cdn_provider_lastUpdatedAt_$appId';
  String get _manifestCacheKey => 'cdn_provider_manifest_$appId';

  static const String _i18nPrefix = 'i18n_';

  @override
  Future<DefinitionProvider> init() async {
    // Load cached state first for faster startup
    await _loadCachedState();

    // Then check for updates
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
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshIfStale();
    }
  }

  // ---------------------------------------------------------------------------
  // Persistent caching
  // ---------------------------------------------------------------------------

  Future<void> _loadCachedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached ETag and lastUpdatedAt
      _etag = prefs.getString(_etagKey);
      _lastUpdatedAt = prefs.getInt(_lastUpdatedAtKey);

      // Try to load cached manifest
      final cachedManifest = prefs.getString(_manifestCacheKey);
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_etagKey, _etag ?? '');
      await prefs.setInt(_lastUpdatedAtKey, _lastUpdatedAt ?? 0);
      await prefs.setString(_manifestCacheKey, manifestJson);
    } catch (e) {
      debugPrint('CdnProvider: Failed to save cached state: $e');
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_etagKey);
      await prefs.remove(_lastUpdatedAtKey);
      await prefs.remove(_manifestCacheKey);
    } catch (e) {
      debugPrint('CdnProvider: Failed to clear cache: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Networking / manifest loading
  // ---------------------------------------------------------------------------

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
      // Note: lastUpdatedAt is not in manifest, it's in lastUpdateTime.json

      _rebuildFromRoot(root);
      _etag = newEtag ?? _etag;
      // _lastUpdatedAt is updated in _shouldFetchManifest() from lastUpdateTime.json

      // Save to persistent cache
      await _saveCachedState(jsonString);
      Ensemble().notifyAppBundleChanges();
    } catch (_) {}
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
    // Note: lastUpdatedAt is not in manifest, it's in lastUpdateTime.json
    _rebuildFromRoot(root);

    // Save to persistent cache
    await _saveCachedState(jsonString);
  }

  Future<bool> _shouldFetchManifest() async {
    final lastUpdateUri = Uri.parse(_lastUpdateTimeUrl);

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
    final uri = Uri.parse(_manifestUrl);

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
    try {
      final decompressed = brotliDecode(resp.bodyBytes);
      return utf8.decode(decompressed);
    } catch (_) {
      return resp.body;
    }
  }

  // ---------------------------------------------------------------------------
  // Rebuild pipeline
  // ---------------------------------------------------------------------------

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
    final secretsMap = _asMap(artifacts['secrets']);
    if (secretsMap != null) {
      _secrets = secretsMap.map((k, v) => MapEntry(k.toString(), v.toString()));
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

  // ---------------------------------------------------------------------------
  // Parsers
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
}
