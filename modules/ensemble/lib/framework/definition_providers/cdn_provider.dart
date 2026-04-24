import 'dart:async';
import 'dart:convert';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/i18n_loader.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:brotli/brotli.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:convert/convert.dart';

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

  // HTTP caching (ETag) + freshness
  String? _etag;
  int? _lastUpdatedAt;

  // Background update tracking
  bool _hasPendingUpdate = false;

  // Encryption support for CDN secrets
  Uint8List? _encryptionKey;
  String? _manifestKey;
  Map<String, String> _cdnSecrets = {};

  // Persistent cache key
  String get _artifactCacheKey => 'cdn_provider_state_$appId';

  static const String _i18nPrefix = 'i18n_';

  @override
  Future<DefinitionProvider> init() async {
    // Load encryption keys from dotenv (if available)
    if (dotenv.isInitialized) {
      _encryptionKey = _parseEncryptionKey(dotenv.env['ENSEMBLE_ENCRYPTION_KEY']);
      _manifestKey = dotenv.env['ENSEMBLE_MANIFEST_KEY'];

      if (_encryptionKey != null && kDebugMode) {
        debugPrint('CdnProvider: Encryption key loaded, will fetch encrypted manifest');
      }
    }

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
  Map<String, String> getSecrets() {
    final secrets = <String, String>{};

    // Add CDN secrets first (lower priority)
    secrets.addAll(_cdnSecrets);

    // Add dotenv secrets (higher priority - can override CDN)
    if (dotenv.isInitialized) {
      secrets.addAll(Map<String, String>.from(dotenv.env));
    }

    return secrets;
  }

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
      await _refreshTranslationsAtRuntime();
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
    // Choose endpoint based on encryption key availability
    final useEncrypted = _encryptionKey != null;
    final filename = useEncrypted ? 'encrypted-manifest.json' : 'manifest.json';
    final uri = Uri.parse('$baseUrl/$appId/$filename');

    final headers = <String, String>{};
    if (ifNoneMatch != null && ifNoneMatch.isNotEmpty) {
      headers['If-None-Match'] = ifNoneMatch;
    }

    // Add manifest key header for WAF access control (if available)
    if (_manifestKey != null && _manifestKey!.isNotEmpty) {
      headers['x-manifest-key'] = _manifestKey!;
    }

    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 304) return null;

    // Handle WAF denial (403 Forbidden)
    if (resp.statusCode == 403) {
      throw ConfigError(
          "Access denied to encrypted manifest. Please check your ENSEMBLE_MANIFEST_KEY.");
    }

    if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) {
      throw ConfigError(
          "Failed to fetch manifest from CDN. Please check your appId and make sure to sync app to CDN.");
    }

    final jsonString = _decodePossiblyBrotli(resp);
    if (jsonString == null || jsonString.isEmpty) return null;

    // If encrypted, decrypt to get the actual manifest JSON
    String manifestJson;
    if (useEncrypted) {
      final decrypted = _decryptManifest(jsonString);
      if (decrypted == null) {
        throw ConfigError("Failed to decrypt manifest. Check your ENSEMBLE_ENCRYPTION_KEY.");
      }
      manifestJson = jsonEncode(decrypted);
    } else {
      manifestJson = jsonString;
    }

    final etag = resp.headers['etag'] ?? resp.headers['ETag'];
    return {'json': manifestJson, 'etag': etag ?? ''};
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
    _cdnSecrets = {};

    final artifacts = _asMap(root['artifacts']);
    if (artifacts == null) return;

    // 1) config
    final configMap = _asMap(artifacts['config']);
    final String? baseUrl = configMap?['baseUrl']?.toString();
    bool? useBrowserUrl;
    if (configMap != null && configMap.containsKey('useBrowserUrl')) {
      final v = configMap['useBrowserUrl'];
      useBrowserUrl = v is bool ? v : v.toString().toLowerCase() == 'true';
    }

    Map<String, dynamic> envVars = Map<String, dynamic>.from(
        _asMap(configMap?['envVariables']) ?? const {});

    // 2) core artifacts
    _parseScreens(artifacts['screens']);
    _parseTheme(artifacts['theme']);
    _parseResources(
        artifacts['widgets'], artifacts['scripts'], artifacts['actions']);
    _parseTranslations(artifacts['translations']);

    // 3) secrets (from encrypted manifest)
    final secretsMap = _asMap(artifacts['secrets']);
    if (secretsMap != null) {
      _cdnSecrets = secretsMap.map((k, v) => MapEntry(k, v?.toString() ?? ''));
      if (kDebugMode && _cdnSecrets.isNotEmpty) {
        debugPrint('CdnProvider: Loaded ${_cdnSecrets.length} secrets from CDN');
      }
    }

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

  void _parseResources(
      dynamic widgetsRaw, dynamic scriptsRaw, dynamic actionsRaw) {
    final widgets = <String, dynamic>{};
    final code = <String, dynamic>{};
    final actions = <String, dynamic>{};

    if (widgetsRaw is Map) {
      widgetsRaw.forEach((k, v) {
        if (v is String && v.isNotEmpty) {
          final yaml = _tryLoadYaml(v);
          // IMPORTANT: Store the full YAML to preserve Import declarations
          if (yaml != null) widgets[k] = yaml;
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
          // IMPORTANT: Store the full YAML to preserve Import declarations
          if (yaml != null) widgets[name] = yaml;
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

    // Parse reusable Actions
    if (actionsRaw is List) {
      for (final item in actionsRaw) {
        final a = _asMap(item);
        if (a == null) continue;
        final name = a['name']?.toString();
        final content = a['content'];
        if (name == null) continue;

        final YamlMap? yaml = _yamlFromUnknown(content);
        if (yaml == null) continue;

        // Flatten optional top-level "Action" wrapper
        final dynamic root = yaml['Action'] ?? yaml;
        if (root is YamlMap) {
          actions[name] = root;
        } else if (root is Map) {
          actions[name] = YamlMap.wrap(root);
        }
      }
    }

    final resources = <String, dynamic>{
      ResourceArtifactEntry.Widgets.name: widgets,
      ResourceArtifactEntry.Scripts.name: code,
    };
    if (actions.isNotEmpty) {
      resources['Actions'] = actions;
    }
    if (resources.isNotEmpty) {
      // Store as plain Map (not YamlMap) to match Ensemble provider behavior
      _artifactCache[ArtifactType.resources.name] = resources;
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

  // --------------------------------------------------------
  // Encryption helpers (for encrypted manifest support)
  // --------------------------------------------------------

  /// Parses a 256-bit encryption key from various formats.
  /// Supports: 64-char hex, base64 (32 bytes), or 32-byte UTF-8 string.
  /// Returns null if the key is invalid or not provided.
  static Uint8List? _parseEncryptionKey(String? keyString) {
    if (keyString == null || keyString.isEmpty) return null;

    // Try hex (64 chars = 32 bytes)
    if (RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(keyString)) {
      try {
        return Uint8List.fromList(hex.decode(keyString));
      } catch (_) {}
    }

    // Try base64 (decodes to 32 bytes)
    try {
      final decoded = base64.decode(keyString);
      if (decoded.length == 32) return Uint8List.fromList(decoded);
    } catch (_) {}

    // Try UTF-8 (exactly 32 bytes)
    final utf8Bytes = utf8.encode(keyString);
    if (utf8Bytes.length == 32) return Uint8List.fromList(utf8Bytes);

    debugPrint('CdnProvider: Invalid encryption key format. '
        'Expected 64-char hex, base64 (32 bytes), or 32-byte UTF-8 string.');
    return null;
  }

  /// Decrypts the encrypted manifest envelope and returns the inner manifest.
  /// The envelope format: { v, alg, comp, iv, tag, ciphertext }
  /// Returns the manifest map (same structure as public manifest, but with secrets).
  Map<String, dynamic>? _decryptManifest(String encryptedJson) {
    if (_encryptionKey == null) return null;

    try {
      final envelope = jsonDecode(encryptedJson) as Map<String, dynamic>;

      // Validate format
      if (envelope['v'] != 1 || envelope['alg'] != 'AES-256-GCM') {
        throw ConfigError('Unsupported encrypted manifest format: '
            'v=${envelope['v']}, alg=${envelope['alg']}');
      }

      // Decode components
      final iv = encrypt.IV.fromBase64(envelope['iv'] as String);
      final tag = base64.decode(envelope['tag'] as String);
      final ciphertext = base64.decode(envelope['ciphertext'] as String);

      // Combine ciphertext + tag (Dart encrypt package expects tag appended)
      final combined = Uint8List.fromList([...ciphertext, ...tag]);

      // Decrypt
      final key = encrypt.Key(_encryptionKey!);
      final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.gcm));
      final decryptedBytes = encrypter.decryptBytes(encrypt.Encrypted(combined), iv: iv);

      // Decompress if needed (comp: "br" means Brotli compressed)
      List<int> plaintext;
      if (envelope['comp'] == 'br') {
        plaintext = brotliDecode(Uint8List.fromList(decryptedBytes));
      } else {
        plaintext = decryptedBytes;
      }

      // Parse JSON and unwrap from 'manifest' key
      final wrapper = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
      return wrapper['manifest'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('CdnProvider: Failed to decrypt manifest: $e');
      rethrow;
    }
  }

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

  @visibleForTesting
  Future<void> applyRuntimeManifestForTesting(Map<String, dynamic> root) async {
    _rebuildFromRoot(root);
    await _refreshTranslationsAtRuntime();
  }

  Future<void> _refreshTranslationsAtRuntime() async {
    try {
      final context = Utils.globalAppKey.currentContext;
      if (context == null) {
        if (kDebugMode) {
          debugPrint(
              'CdnProvider: Skip i18n runtime refresh (no app context available)');
        }
        return;
      }

      await FlutterI18n.refresh(context, Ensemble().locale);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CdnProvider: Failed to refresh i18n runtime state: $e');
      }
    }
  }
}
