import 'dart:convert';
import 'dart:async';
import 'dart:developer';
import 'dart:ui';
import 'package:ensemble/ensemble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/yaml_decode_strategy.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' as foundation;

abstract class DefinitionProvider {
  static Map<String,dynamic> cache = {};
  final I18nProps i18nProps;
  bool cacheEnabled = false;
  DefinitionProvider(this.i18nProps,{this.cacheEnabled=false});
  Future<YamlMap> getDefinition({String? screenId, String? screenName});
  FlutterI18nDelegate getI18NDelegate();
  Future<AppBundle> getAppBundle();
}

class LocalDefinitionProvider extends DefinitionProvider {
  LocalDefinitionProvider(this.path, this.appHome,I18nProps i18nProps): super(i18nProps);
  final String path;
  final String appHome;

  FlutterI18nDelegate? _i18nDelegate;
  @override
  FlutterI18nDelegate getI18NDelegate() {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: FileTranslationLoader(
          useCountryCode: false,
          fallbackFile: i18nProps.fallbackLocale,
          basePath: i18nProps.path,
          forcedLocale: Locale(i18nProps.defaultLocale),
          decodeStrategies: [YamlDecodeStrategy()],)
    );
    return _i18nDelegate!;
  }

  @override
  Future<YamlMap> getDefinition({String? screenId, String? screenName}) async {
    // Note: Web with local definition caches even if we disable browser cache
    // so you may need to re-run the app on definition changes
    var pageStr = await rootBundle.loadString(
        '$path${screenId ?? screenName ?? appHome}.yaml',
        cache: foundation.kReleaseMode);
    return loadYaml(pageStr);
  }

  @override
  Future<AppBundle> getAppBundle() async {
    try {
      var content = await rootBundle.loadString('${path}theme.config');
      return AppBundle(theme: await loadYaml(content));
    } catch (error) {
      return AppBundle();
    }
  }
}



class RemoteDefinitionProvider extends DefinitionProvider {
  // TODO: we can fetch the whole App bundle here
  RemoteDefinitionProvider(this.path, this.appHome,bool cacheEnabled,I18nProps i18nProps): super(i18nProps,cacheEnabled:cacheEnabled);
  final String path;
  final String appHome;
  FlutterI18nDelegate? _i18nDelegate;
  @override
  FlutterI18nDelegate getI18NDelegate() {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: NetworkFileTranslationLoader(
            baseUri: Uri.parse(i18nProps.path),
            forcedLocale: Locale(i18nProps.defaultLocale),
            fallbackFile: i18nProps.fallbackLocale,
            useCountryCode: i18nProps.useCountryCode,
            decodeStrategies: [YamlDecodeStrategy()])
    );
    return _i18nDelegate!;
  }
  @override
  Future<YamlMap> getDefinition({String? screenId, String? screenName}) async {
    String screen = screenId ?? screenName ?? appHome;

    Completer<YamlMap> completer = Completer();
    dynamic res = DefinitionProvider.cache[screen];
    if ( res != null ) {
      completer.complete(res);
      return completer.future;
    }
    http.Response response = await http.get(
        Uri.parse('$path$screen.yaml'));
    if (response.statusCode == 200) {
      dynamic res = loadYaml(response.body);
      if ( cacheEnabled ) {
        DefinitionProvider.cache[screen] = res;
      }
      completer.complete(res);
    } else {
      completer.completeError("Error loading Remote screen $screen");
    }
    return completer.future;
  }

  @override
  Future<AppBundle> getAppBundle() async {
    // theme config is optional
    Completer<AppBundle> completer = Completer();
    http.Response response = await http.get(
        Uri.parse('${path}theme.config'));
    if (response.statusCode == 200) {
      AppBundle appBundle = AppBundle(theme: await loadYaml(response.body));
      completer.complete(appBundle);
    } else {
      completer.complete(AppBundle());
    }
    return completer.future;
  }
}

class EnsembleDefinitionProvider extends DefinitionProvider {

  EnsembleDefinitionProvider(this.url, this.appId,bool cacheEnabled,I18nProps i18nProps): super(i18nProps,cacheEnabled:cacheEnabled);
  final String url;
  final String appId;
  String? appHome;
  FlutterI18nDelegate? _i18nDelegate;

  @override
  FlutterI18nDelegate getI18NDelegate() {
    _i18nDelegate ??= FlutterI18nDelegate(
        translationLoader: NetworkFileTranslationLoader(
            baseUri: Uri.parse(i18nProps.path),
            forcedLocale: Locale(i18nProps.defaultLocale),
            fallbackFile: i18nProps.fallbackLocale,
            useCountryCode: i18nProps.useCountryCode,
            decodeStrategies: [YamlDecodeStrategy()])
    );
    return _i18nDelegate!;
  }
  @override
  Future<YamlMap> getDefinition({String? screenId, String? screenName}) async {
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
    Completer<YamlMap> completer = Completer();
    dynamic res = DefinitionProvider.cache[params];
    if ( res != null ) {
      completer.complete(res);
      return completer.future;
    }
    http.Response response = await http.get(Uri.parse('$url/screen/content?$params'));
    if (response.statusCode == 200) {
      dynamic res = loadYaml(response.body);
      if ( cacheEnabled ) {
        DefinitionProvider.cache[params] = res;
      }
      completer.complete(res);
    } else {
      completer.completeError("Error loading Ensemble page: ${screenId ?? screenName ?? 'Home'}");
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
  Future<AppBundle> getAppBundle() async {
    Completer<AppBundle> completer = Completer();
    http.Response response = await http.get(Uri.parse('$url/app/def?id=$appId'));
    if (response.statusCode == 200) {
      Map<String, dynamic> result = json.decode(response.body);

      if (result[appId] != null) {
        // iterate and get the home screen
        if (result[appId]['screens'] is List) {
          for (dynamic screen in result[appId]['screens']) {
            if (screen['is_home']) {
              appHome = screen['name'];
              print("appHome: $appHome");
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

}




