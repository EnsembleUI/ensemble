import 'dart:async';
import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

class RemoteDefinitionProvider extends FileDefinitionProvider {
  // TODO: we can fetch the whole App bundle here
  RemoteDefinitionProvider(
    super.path,
    super.appHome, {
    super.i18nProps,
    super.initialForcedLocale,
    this.cacheEnabled = false,
  });

  final bool cacheEnabled;
  static Map<String, dynamic> cache = {};

  @override
  FileTranslationLoader getTranslationLoader(I18nProps i18nProps,
          {Locale? forcedLocale}) =>
      NetworkFileTranslationLoader(
          useCountryCode: false,
          fallbackFile: i18nProps.fallbackLanguage ?? 'en',
          baseUri: Uri.parse(i18nProps.path),
          forcedLocale: forcedLocale ?? initialForcedLocale,
          decodeStrategies: [YamlDecodeStrategy()]);

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    String screen = screenId ?? screenName ?? appHome;

    Completer<ScreenDefinition> completer = Completer();
    dynamic res = cache[screen];
    if (res != null) {
      completer.complete(res);
      return completer.future;
    }
    http.Response response = await http.get(Uri.parse('$path$screen.yaml'));
    if (response.statusCode == 200) {
      dynamic res = ScreenDefinition(loadYaml(response.body));
      if (cacheEnabled) {
        cache[screen] = res;
      }
      completer.complete(res);
    } else {
      completer.complete(ScreenDefinition(YamlMap()));
    }
    return completer.future;
  }

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    final env = await _readYamlFile('appConfig.yaml');
    if (env != null) {
      appConfig = UserAppConfig(
        baseUrl: path,
        envVariables: env as Map<String, dynamic>,
      );
    }
    return AppBundle(
        theme: await _readYamlFile('theme.ensemble'),
        resources: await _readYamlFile('resources.ensemble'));
  }

  Future<YamlMap?> _readYamlFile(String file) async {
    try {
      http.Response response = await http.get(Uri.parse(path + file));
      if (response.statusCode == 200) {
        return loadYaml(response.body);
      }
    } catch (error) {
      // ignore
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
  String? getHomeScreenName() {
    return appHome; // For remote provider, appHome is the home screen name
  }

  @override
  Future<DefinitionProvider> init() async {
    return this;
  }
}
