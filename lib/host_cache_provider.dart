import 'dart:async';
import 'dart:convert';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaml/yaml.dart';

/// Connecting to Ensemble-hosted definitions with a host persistent cache
class HostCachedEnsembleProvider extends EnsembleDefinitionProvider {
  HostCachedEnsembleProvider._create(String appId, I18nProps i18nProps)
      : super(appId, i18nProps);

  late SharedPreferences hostCache;

  static Future<HostCachedEnsembleProvider> create(
      String appId, I18nProps i18nProps) async {
    final instance = HostCachedEnsembleProvider._create(appId, i18nProps);
    await instance._initCache();
    return instance;
  }

  _initCache() async {
    hostCache = await SharedPreferences.getInstance();
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
    await hostCache.reload();
    String? theme;
    if (appModel.themeMapping != null &&
        (theme ??= hostCache.getString(appModel.themeMapping!)) != null) {
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
      content = hostCache.getString(screenId);
    } else if (screenName != null) {
      final screenId = appModel.screenNameMappings[screenName];
      if (screenId != null) {
        content = hostCache.getString(screenId);
      }
    } else if (appModel.homeMapping != null) {
      content = hostCache.getString(appModel.homeMapping!);
    }

    if (content == null) {
      throw LanguageError('invalid-content',
          detailError:
              "Invalid screen content: ${screenId ?? screenName ?? 'Home'}");
    }
    return ScreenDefinition(loadYaml(content));
  }

  _syncArtifactsToHostCache() {
    appModel.artifactCache.forEach((key, value) {
      if (value == null || value is InvalidDefinition) {
        return;
      }
      hostCache.setString(key, json.encode(value));
    });
  }
}
