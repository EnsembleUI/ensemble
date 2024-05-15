import 'dart:convert';
import 'dart:async';

import 'dart:ui';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum ArtifactType {
  screen,
  theme,
  i18n,
  resources, // global widgets/codes/APIs/
  config, // app config
  secrets
}

// the root entries of the Resource artifact
enum ResourceArtifactEntry { Widgets, Scripts, API }

abstract class DefinitionProvider {
  static Map<String, dynamic> cache = {};
  final I18nProps i18nProps;
  bool cacheEnabled = false;

  String? appId;

  DefinitionProvider(this.i18nProps, {this.cacheEnabled = false});

  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName});

  FlutterI18nDelegate getI18NDelegate({Locale? forcedLocale});

  // get the home screen + the App Bundle (theme, translation, custom assets, ...)
  Future<AppBundle> getAppBundle({bool? bypassCache = false});

  // this should be update live if the config changes at runtime
  // Call this only AFTER getAppBundle()
  // TODO: rethink this
  UserAppConfig? getAppConfig();

  Map<String, String> getSecrets();
}

class LocalDefinitionProvider extends DefinitionProvider {
  LocalDefinitionProvider(this.path, this.appHome, I18nProps i18nProps)
      : super(i18nProps);
  final String path;
  final String appHome;
  UserAppConfig? appConfig;

  FlutterI18nDelegate? _i18nDelegate;

  @override
  FlutterI18nDelegate getI18NDelegate({Locale? forcedLocale}) {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: FileTranslationLoader(
      useCountryCode: false,
      fallbackFile: i18nProps.fallbackLocale,
      basePath: i18nProps.path,
      // use the forcedLocale passed in at the App level, then use the forcedLocale in the config
      forcedLocale: forcedLocale ??
          (i18nProps.forcedLocale != null
              ? Locale(i18nProps.forcedLocale!)
              : null),
      decodeStrategies: [YamlDecodeStrategy()],
    ));
    return _i18nDelegate!;
  }

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
  Map<String, String> getSecrets() {
    return dotenv.env;
  }
}

class RemoteDefinitionProvider extends DefinitionProvider {
  // TODO: we can fetch the whole App bundle here
  RemoteDefinitionProvider(
      this.path, this.appHome, bool cacheEnabled, I18nProps i18nProps)
      : super(i18nProps, cacheEnabled: cacheEnabled);
  final String path;
  final String appHome;
  UserAppConfig? appConfig;
  FlutterI18nDelegate? _i18nDelegate;

  @override
  FlutterI18nDelegate getI18NDelegate({Locale? forcedLocale}) {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: NetworkFileTranslationLoader(
            baseUri: Uri.parse(i18nProps.path),
            forcedLocale: forcedLocale,
            fallbackFile: i18nProps.fallbackLocale,
            useCountryCode: i18nProps.useCountryCode,
            decodeStrategies: [YamlDecodeStrategy()]));
    return _i18nDelegate!;
  }

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    String screen = screenId ?? screenName ?? appHome;

    Completer<ScreenDefinition> completer = Completer();
    dynamic res = DefinitionProvider.cache[screen];
    if (res != null) {
      completer.complete(res);
      return completer.future;
    }
    http.Response response = await http.get(Uri.parse('$path$screen.yaml'));
    if (response.statusCode == 200) {
      dynamic res = ScreenDefinition(loadYaml(response.body));
      if (cacheEnabled) {
        DefinitionProvider.cache[screen] = res;
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
  Map<String, String> getSecrets() {
    return dotenv.env;
  }
}

class LegacyDefinitionProvider extends DefinitionProvider {
  LegacyDefinitionProvider(
      this.url, this.appId, bool cacheEnabled, I18nProps i18nProps)
      : super(i18nProps, cacheEnabled: cacheEnabled);
  final String url;
  final String appId;
  String? appHome;
  FlutterI18nDelegate? _i18nDelegate;

  @override
  FlutterI18nDelegate getI18NDelegate({Locale? forcedLocale}) {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: NetworkFileTranslationLoader(
            baseUri: Uri.parse(i18nProps.path),
            forcedLocale: forcedLocale,
            fallbackFile: i18nProps.fallbackLocale,
            useCountryCode: i18nProps.useCountryCode,
            decodeStrategies: [YamlDecodeStrategy()]));
    return _i18nDelegate!;
  }

  @override
  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName}) async {
    String params = 'ast=false&expression_to_ast=false';
    if (screenId != null) {
      params += '&id=$screenId';
    } else {
      params += '&appId=$appId';
      // home screen is loaded if screenName is not specified
      if (screenName != null) {
        params += '&name=$screenName';
      }
    }
    Completer<ScreenDefinition> completer = Completer();
    dynamic res = DefinitionProvider.cache[params];
    if (res != null) {
      completer.complete(res);
      return completer.future;
    }
    http.Response response =
        await http.get(Uri.parse('$url/screen/content?$params'));
    if (response.statusCode == 200) {
      dynamic res = ScreenDefinition(loadYaml(response.body));
      if (cacheEnabled) {
        DefinitionProvider.cache[params] = res;
      }
      completer.complete(res);
    } else {
      completer.complete(ScreenDefinition(YamlMap()));
    }
    return completer.future;
  }

  /// Legacy - have to loop through all the screen to match
  /*Future<YamlMap> getLegacyDefinition({String? screenId}) async {
    Completer<YamlMap> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('$url/app?id=$appId'));
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);
      if (result[appId] != null
          && result[appId]['screens'] is List
          && (result[appId]['screens'] as List).isNotEmpty) {
        List<dynamic> screens = result[appId]['screens'];

        for (dynamic screen in screens) {
          // if loading App without specifying page, load the root page
          if (screenId == null) {
            if (screen['is_home']) {
              completer.complete(loadYaml(screen['content']));
              return completer.future;
            }
          } else if (screen['id'] == screenId || screen['name'] == screenId) {
            completer.complete(loadYaml(screen['content']));
            return completer.future;
          }
        }
      }
    }
    completer.completeError("Error loading Ensemble page: ${screenId ?? 'Home'}");
    return completer.future;
  }*/

  @override
  Future<AppBundle> getAppBundle({bool? bypassCache = false}) async {
    Completer<AppBundle> completer = Completer();
    http.Response response =
        await http.get(Uri.parse('$url/app/def?id=$appId'));
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);

      if (result[appId] != null) {
        // iterate and get the home screen
        if (result[appId]['screens'] is List) {
          for (dynamic screen in result[appId]['screens']) {
            if (screen['is_home']) {
              appHome = screen['name'];
              break;
            }
          }
        }
        // get the App bundle
        String? content = result[appId]['theme']?['content'];
        if (content != null) {
          completer.complete(AppBundle(theme: await loadYaml(content)));
          return completer.future;
        }
      }
    }
    completer.complete(AppBundle());
    return completer.future;
  }

  // To be implemented
  @override
  UserAppConfig? getAppConfig() {
    return null;
  }

  // TODO: to be implemented
  @override
  Map<String, String> getSecrets() {
    return <String, String>{};
  }
}
