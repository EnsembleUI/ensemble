import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/foundation.dart' as foundation;

/**
 * Store all the definitions and assets locally together with the App
 */
class LocalDefinitionProvider extends FileDefinitionProvider {
  LocalDefinitionProvider(super.path, super.appHome,
      {super.i18nProps, super.initialForcedLocale});

  @override
  FileTranslationLoader getTranslationLoader(I18nProps i18nProps,
          {Locale? forcedLocale}) =>
      FileTranslationLoader(
        useCountryCode: false,
        fallbackFile: i18nProps.fallbackLanguage ?? 'en',
        basePath: i18nProps.path,
        // use the forcedLocale passed in at the App level, then use the forcedLocale in the config
        forcedLocale: forcedLocale ?? initialForcedLocale,
        decodeStrategies: [YamlDecodeStrategy()],
      );

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    // Note: Web with local definition caches even if we disable browser cache
    // so you may need to re-run the app on definition changes
    var pageStr = await rootBundle.loadString(
        '$path${screenId ?? screenName ?? appHome}.yaml',
        cache: foundation.kReleaseMode);
    if (pageStr.isEmpty) {
      return ScreenDefinition(YamlMap());
    }
    return ScreenDefinition(loadYaml(pageStr));
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    YamlMap? config = await _readFile('config.ensemble');
    if (config != null) {
      appConfig = UserAppConfig(
          baseUrl: config['app']?['baseUrl'],
          useBrowserUrl: Utils.optionalBool(config['app']?['useBrowserUrl']));
    }
    return AppBundle(
        theme: await _readFile('theme.ensemble'),
        resources: await _readFile('resources.ensemble'));
  }

  Future<YamlMap?> _readFile(String file) async {
    try {
      var value = await rootBundle.loadString(path + file);
      return loadYaml(value);
    } catch (error) {
      // ignore error
    }
    return null;
  }

  @override
  UserAppConfig? getAppConfig() {
    return appConfig;
  }

  @override
  void onAppLifecycleStateChanged(AppLifecycleState state) {
    // no-op
  }

  @override
  Future<DefinitionProvider> init() async {
    return this;
  }
}
