import 'dart:async';
import 'dart:convert';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/ensemble_provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:session_storage/session_storage.dart';
import 'package:yaml/yaml.dart';

/// Connecting to Ensemble-hosted definitions with a host persistent cache
class HostCachedEnsembleProvider extends EnsembleDefinitionProvider {
  HostCachedEnsembleProvider._create(String appId) : super(appId,isListenerMode: true);

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
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    // Populate cache from remote if first time or explicitly asked
    if (bypassCache == true || appModel.artifactCache.isEmpty) {
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
}
