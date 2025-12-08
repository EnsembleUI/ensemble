import 'dart:async';
import 'dart:convert';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/ensemble_provider.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:session_storage/session_storage.dart';
import 'package:yaml/yaml.dart';

/// Connecting to Ensemble-hosted definitions with a host persistent cache
class HostCachedEnsembleProvider extends EnsembleDefinitionProvider {
  HostCachedEnsembleProvider._create(String appId)
      : super(appId, isListenerMode: true);

  late SessionStorage hostCache;

  static Future<HostCachedEnsembleProvider> create(
      String appId, I18nProps i18nProps) async {
    final instance = HostCachedEnsembleProvider._create(appId);
    await instance.init();
    await instance._initCache();
    return instance;
  }

  _initCache() async {
    hostCache = SessionStorage();
    _loadAppConfig();
    _loadSecrets();
  }

  /// --- Config (envVariables) ---
  void _loadAppConfig() {
    if (appModel.appConfig != null) return;

    // 1) Session Storage direct payload {appId}.appConfig
    _setAppConfigFromSerialized(hostCache['${appId}.appConfig']);
    if (appModel.appConfig != null) return;

    // 2) Artifact cache entry
    _setAppConfigFromArtifact(appModel.artifactCache[ArtifactType.config.name]);
    if (appModel.appConfig != null) return;

    // 3) Serialized artifact stored under the cache key
    _setAppConfigFromSerialized(
        hostCache[_getCacheKey(ArtifactType.config.name)]);
  }

  /// --- Secrets ---
  void _loadSecrets() {
    if (appModel.secrets != null && appModel.secrets!.isNotEmpty) return;

    // 1) Session Storage direct payload {appId}.secrets
    _setSecretsFromSerialized(hostCache['${appId}.secrets']);
    if (appModel.secrets != null && appModel.secrets!.isNotEmpty) return;

    // 2) Artifact cache entry
    _setSecretsFromArtifact(appModel.artifactCache[ArtifactType.secrets.name]);
    if (appModel.secrets != null && appModel.secrets!.isNotEmpty) return;

    // 3) Serialized artifact stored under the cache key
    _setSecretsFromSerialized(
        hostCache[_getCacheKey(ArtifactType.secrets.name)]);
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    // If we are missing critical data (config/secrets/env), force remote fetch
    final missingConfigOrSecrets = appModel.appConfig == null ||
        appModel.appConfig?.envVariables == null ||
        (appModel.appConfig?.envVariables?.isEmpty ?? true) ||
        appModel.secrets == null ||
        (appModel.secrets?.isEmpty ?? true);

    // Populate cache from remote if first time, explicitly asked, or missing critical artifacts
    if (bypassCache == true ||
        appModel.artifactCache.isEmpty ||
        missingConfigOrSecrets) {
      AppBundle updatedBundle = await appModel.getAppBundle();
      _syncArtifactsToHostCache();
      return updatedBundle;
    }
    // Fetches any changed values from the host, e.g. in case of studio changes
    String? theme;
    if (appModel.themeMapping != null &&
        (theme ??= hostCache[_getCacheKey(appModel.themeMapping!)]) != null) {
      return AppBundle(
          theme: loadYaml(theme!),
          resources: await appModel.getCombinedResources());
    } else {
      return AppBundle(resources: await appModel.getCombinedResources());
    }
  }

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    String? content;

    if (screenId != null) {
      content = hostCache[_getCacheKey(screenId)];
    } else if (screenName != null) {
      final screenId = appModel.screenNameMappings[screenName];
      if (screenId != null) {
        content = hostCache[_getCacheKey(screenId)];
      }
    } else if (appModel.homeMapping != null) {
      content = hostCache[_getCacheKey(appModel.homeMapping!)];
    }

    return content != null
        ? ScreenDefinition(loadYaml(content))
        : ScreenDefinition(YamlMap());
  }

  _syncArtifactsToHostCache() {
    appModel.artifactCache.forEach((key, value) {
      if (value == null || value is InvalidDefinition) {
        return;
      }
      hostCache.addAll({_getCacheKey(key): json.encode(value)});
    });
  }

  _getCacheKey(String id) {
    return '${appId}.${id}';
  }

  @override
  UserAppConfig? getAppConfig() {
    // First check if appConfig is already loaded
    if (appModel.appConfig != null) {
      return appModel.appConfig;
    }

    // Try to load from Session Storage
    _loadAppConfig();

    // Return the loaded config (or null if not found)
    return appModel.appConfig;
  }

  @override
  Map<String, String> getSecrets() {
    // First check if secrets are already loaded
    if (appModel.secrets != null && appModel.secrets!.isNotEmpty) {
      return appModel.secrets!;
    }

    // Try to load from Session Storage
    _loadSecrets();

    // Return the loaded secrets (or empty map if not found)
    return appModel.secrets ?? {};
  }

  void _setAppConfigFromArtifact(dynamic artifact) {
    if (artifact is Map) {
      Map<String, dynamic>? envVariables;
      dynamic env = artifact['envVariables'];
      if (env is Map) {
        envVariables = Map<String, dynamic>.from(env);
      }
      appModel.appConfig = UserAppConfig(
        baseUrl: artifact['appBaseUrl'] as String?,
        useBrowserUrl: artifact['appUseBrowserUrl'] as bool?,
        envVariables: envVariables,
      );
    } else if (artifact is YamlMap) {
      Map<String, dynamic>? envVariables;
      dynamic env = artifact['envVariables'];
      if (env is YamlMap) {
        envVariables = Map<String, dynamic>.from(env.value);
      }
      appModel.appConfig = UserAppConfig(
        baseUrl: artifact['appBaseUrl'],
        useBrowserUrl: Utils.optionalBool(artifact['appUseBrowserUrl']),
        envVariables: envVariables,
      );
    }
  }

  void _setAppConfigFromSerialized(String? storedData) {
    if (storedData == null || storedData.isEmpty) return;
    try {
      dynamic decoded = json.decode(storedData);
      if (decoded is Map<String, dynamic>) {
        Map<String, dynamic> parsed = decoded;
        if ((parsed.containsKey('type') && parsed['type'] == 'config') ||
            parsed.containsKey('baseUrl') ||
            parsed.containsKey('envVariables')) {
          Map<String, dynamic>? envVariables;
          dynamic env = parsed['envVariables'];
          if (env is Map) {
            envVariables = Map<String, dynamic>.from(env);
          }
          appModel.appConfig = UserAppConfig(
            baseUrl: (parsed['appBaseUrl'] ?? parsed['baseUrl']) as String?,
            useBrowserUrl: parsed['appUseBrowserUrl'] as bool? ??
                parsed['useBrowserUrl'] as bool?,
            envVariables: envVariables,
          );
        }
      }
    } catch (_) {
      // ignore
    }
  }

  void _setSecretsFromArtifact(dynamic artifact) {
    if (artifact is Map) {
      dynamic rawSecrets = artifact['secrets'];
      if (rawSecrets is Map) {
        appModel.secrets = {};
        rawSecrets.forEach((key, value) {
          appModel.secrets![key.toString()] = value.toString();
        });
      }
    } else if (artifact is YamlMap) {
      dynamic rawSecrets = artifact['secrets'];
      if (rawSecrets is YamlMap) {
        appModel.secrets = {};
        rawSecrets.value.forEach((key, value) {
          appModel.secrets![key.toString()] = value.toString();
        });
      }
    }
  }

  void _setSecretsFromSerialized(String? storedData) {
    if (storedData == null || storedData.isEmpty) return;
    try {
      dynamic decoded = json.decode(storedData);
      if (decoded is Map<String, dynamic>) {
        Map<String, dynamic> parsed = decoded;
        if ((parsed.containsKey('type') && parsed['type'] == 'secrets') ||
            parsed.isNotEmpty) {
          dynamic rawSecrets = parsed['secrets'] ?? parsed;
          if (rawSecrets is Map) {
            appModel.secrets = {};
            rawSecrets.forEach((key, value) {
              appModel.secrets![key.toString()] = value.toString();
            });
          }
        }
      }
    } catch (_) {
      // ignore
    }
  }
}
