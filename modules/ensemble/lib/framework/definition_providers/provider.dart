import 'dart:async';

import 'dart:ui';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/definition_providers/ensemble_provider.dart';
import 'package:ensemble/framework/definition_providers/local_provider.dart';
import 'package:ensemble/framework/definition_providers/remote_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

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

enum _Provider { local, remote, ensemble }

/**
 * base definition provider
 */
abstract class DefinitionProvider {
  // force the app to use this locale instead of system-detected one
  Locale? initialForcedLocale;

  DefinitionProvider({this.initialForcedLocale});

  Future<ScreenDefinition> getDefinition(
      {String? screenId, String? screenName});

  FlutterI18nDelegate? getI18NDelegate({Locale? forcedLocale});

  // get the home screen + the App Bundle (theme, translation, custom assets, ...)
  Future<AppBundle> getAppBundle({bool? bypassCache = false});

  // this should be update live if the config changes at runtime
  // Call this only AFTER getAppBundle()
  // TODO: rethink this
  UserAppConfig? getAppConfig();

  Map<String, String> getSecrets();

  List<String> getSupportedLanguages();

  void onAppLifecycleStateChanged(AppLifecycleState state);

  // build the definition model from YAML
  static DefinitionProvider from(Map rootMap) {
    if (rootMap['definitions'] != null) {
      var definitionsMap = rootMap['definitions'];
      String? type = Utils.optionalString(definitionsMap['from']);
      if (type == _Provider.ensemble.name) {
        String? appId = definitionsMap[type]?['appId'];
        if (appId == null) {
          throw ConfigError("appId is required. Your App Key can be found on "
              "Ensemble Studio under each application");
        }
        return EnsembleDefinitionProvider(appId,
            initialForcedLocale:
                _localeFromString(definitionsMap[type]?['forcedLocale']));
      } else if (type == _Provider.local.name ||
          type == _Provider.remote.name) {
        return FileDefinitionProvider.from(type!, definitionsMap);
      }
    }
    throw ConfigError(
        "A definition provider is required. Please review Ensemble documentation.");
  }

  static Locale? _localeFromString(dynamic localeStr) {
    if (localeStr is String &&
        (localeStr.length == 2 || localeStr.length == 5)) {
      var languageCode = localeStr.substring(0, 2);
      var countryCode =
          localeStr.length == 5 ? localeStr.substring(3, 5) : null;
      return Utils.getLocale(languageCode, countryCode);
    }
    return null;
  }
}

/**
 * file-based provider. Base class for both Local/Remote providers
 */
abstract class FileDefinitionProvider extends DefinitionProvider {
  FileDefinitionProvider(this.path, this.appHome,
      {this.i18nProps, super.initialForcedLocale});

  final String path;
  final String appHome;
  final I18nProps? i18nProps;

  UserAppConfig? appConfig;

  FlutterI18nDelegate? _i18nDelegate;

  @override
  FlutterI18nDelegate? getI18NDelegate({Locale? forcedLocale}) {
    if (i18nProps != null) {
      _i18nDelegate ??= FlutterI18nDelegate(
          translationLoader:
              getTranslationLoader(i18nProps!, forcedLocale: forcedLocale));
      return _i18nDelegate;
    }
    return null;
  }

  // implement by subclass
  FileTranslationLoader getTranslationLoader(I18nProps i18nProps,
      {Locale? forcedLocale});

  @override
  Map<String, String> getSecrets() {
    return dotenv.env;
  }

  @override
  List<String> getSupportedLanguages() => i18nProps?.supportedLanguages ?? [];

  static FileDefinitionProvider from(String type, Map definitionsMap) {
    var providerMap = definitionsMap[type];
    if (providerMap == null) {
      throw ConfigError(
          "Missing configuration for provider '$type'. Please review Ensemble documentation.");
    }
    var path = type == _Provider.local.name
        ? _formatPath(providerMap['path'])
        : Utils.optionalString(providerMap['path']);
    if (path == null) {
      throw ConfigError(
          "'path' is required and should point to ${type == _Provider.local.name ? 'a local directory' : 'your Https server'} where the screen definitions and assets are stored.");
    }
    var appHome = Utils.optionalString(providerMap['appHome']);
    if (appHome == null) {
      throw ConfigError(
          "'appHome' is required. This is the home screen's name or id.");
    }
    var forcedLocale =
        DefinitionProvider._localeFromString(providerMap['forcedLocale']);
    var i18nProps = _getI18Props(providerMap);
    if (type == _Provider.local.name) {
      return LocalDefinitionProvider(path, appHome,
          i18nProps: i18nProps, initialForcedLocale: forcedLocale);
    } else {
      bool cacheEnabled = definitionsMap['enableCache'] == true;
      return RemoteDefinitionProvider(path, appHome,
          i18nProps: i18nProps,
          initialForcedLocale: forcedLocale,
          cacheEnabled: cacheEnabled);
    }
  }

  static I18nProps? _getI18Props(Map providerMap) {
    String? path = Utils.optionalString(providerMap['i18n']?['path']);
    if (path != null && path.trim().isNotEmpty) {
      return I18nProps(path.trim(),
          supportedLanguages:
              Utils.getListOfStrings(providerMap['i18n']?['languages']),
          fallbackLanguage:
              Utils.optionalString(providerMap['i18n']?['fallbackLanguage']));
    }
    return null;
  }

  // format the path to ensure it's always valid
  static String? _formatPath(dynamic path) {
    String? _path = Utils.optionalString(path)?.trim();
    if (_path != null) {
      // strip prefix \/
      _path = _path.replaceFirst(RegExp(r'^[\\/]+'), '');

      // add trailing / if not exists
      if (!_path.endsWith('/')) {
        _path += '/';
      }
      return _path;
    }
    return null;
  }
}
