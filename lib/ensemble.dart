import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/ensemble_provider.dart';
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/provider.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:yaml/yaml.dart';
import 'package:firebase_core/firebase_core.dart';

import 'framework/theme/theme_loader.dart';
import 'layout/ensemble_page_route.dart';

/// Singleton Controller
class Ensemble {
  static final Ensemble _instance = Ensemble._internal();
  Ensemble._internal();
  factory Ensemble() {
    return _instance;
  }

  void notifyAppBundleChanges() {
    _config?.updateAppBundle();
  }

  /// the configuration required to run an App
  EnsembleConfig? _config;

  /// initialize Ensemble with the specified config
  void setEnsembleConfig(EnsembleConfig config) {
    _config = config;
  }

  /// init an App from config file
  /// This can be called multiple times but only initialized once.
  /// For integrating with existing Flutter apps, this function can
  /// be called to pre-initialize for faster loading of Ensemble app later.
  Future<EnsembleConfig> initialize() async {
    // only initialize once
    if (_config != null) {
      return Future<EnsembleConfig>.value(_config);
    }

    final yamlString =
        await rootBundle.loadString('ensemble/ensemble-config.yaml');
    final YamlMap yamlMap = loadYaml(yamlString);

    // init Firebase
    if (yamlMap['definitions']?['from'] == 'ensemble') {
      // These are not secrets so OK to include here.
      // https://firebase.google.com/docs/projects/api-keys#api-keys-for-firebase-are-different
      await Firebase.initializeApp(
          options: const FirebaseOptions(
              apiKey: 'AIzaSyBAZ7wf436RSbcXvhhfg7e4TUh6A2SKve8',
              appId: '1:326748243798:ios:30f2a4f824dc58ea94b8f7',
              messagingSenderId: '326748243798',
              projectId: 'ensemble-web-studio'));
    }

    // environment variable overrides
    Map<String, dynamic>? envOverrides;
    dynamic env = yamlMap['environmentVariables'];
    if (env is YamlMap) {
      envOverrides = {};
      env.forEach((key, value) => envOverrides![key.toString()] = value);
    }

    DefinitionProvider definitionProvider = _createDefinitionProvider(yamlMap);
    _config = EnsembleConfig(
        definitionProvider: definitionProvider,
        appBundle: await definitionProvider.getAppBundle(),
        account: Account(
            mapAccessToken: yamlMap['accounts']?['maps']
                ?['mapbox_access_token']),
        envOverrides: envOverrides);
    return _config!;
  }

  /// return the definition provider (local, remote, or Ensemble)
  DefinitionProvider _createDefinitionProvider(YamlMap yamlMap) {
    // locale
    I18nProps i18nProps = I18nProps(
        yamlMap['i18n']?['defaultLocale'] ?? '',
        yamlMap['i18n']?['fallbackLocale'] ?? 'en',
        yamlMap['i18n']?['useCountryCode'] ?? false);

    // Ensemble-powered apps
    String? definitionType = yamlMap['definitions']?['from'];
    if (definitionType == 'ensemble') {
      String? appId = yamlMap['definitions']?['ensemble']?['appId'];
      if (appId == null) {
        throw ConfigError("appId is required. Your App Key can be found on "
            "Ensemble Studio under each application");
      }
      String? i18nPath = yamlMap['definitions']?['ensemble']?['i18nPath'];
      if (i18nPath == null) {
        throw ConfigError(
            "i18nPath is required. If you don't have any changes, just leave the default as-is.");
      }
      i18nProps.path = i18nPath;
      return EnsembleDefinitionProvider(appId, i18nProps);
    }
    // legacy Ensemble-server
    else if (definitionType == 'legacy') {
      String? path = yamlMap['definitions']?['legacy']?['path'];
      if (path == null || !path.startsWith('https')) {
        throw ConfigError(
            'Invalid URL to Ensemble legacy server. The original value should not be changed');
      }
      String? appId = yamlMap['definitions']?['legacy']?['appId'];
      if (appId == null) {
        throw ConfigError("appId is required. Your App Key can be found on "
            "Ensemble Studio under each application");
      }
      String? i18nPath = yamlMap['definitions']?['legacy']?['i18nPath'];
      if (i18nPath == null) {
        throw ConfigError(
            "i18nPath is required. If you don't have any changes, just leave the default as-is.");
      }
      bool cacheEnabled =
          yamlMap['definitions']?['legacy']?['enableCache'] == true;
      i18nProps.path = i18nPath;
      return LegacyDefinitionProvider(path, appId, cacheEnabled, i18nProps);
    }
    // local/remote Apps
    else if (definitionType == 'local' || definitionType == 'remote') {
      String? path = yamlMap['definitions']?[definitionType]?['path'];
      if (path == null) {
        throw ConfigError("Path to the root definition directory is required.");
      }
      String? appId = yamlMap['definitions']?[definitionType]?['appId'];
      if (appId == null) {
        throw ConfigError(
            "appId is required. This is your App's directory under the root path.");
      }
      String? appHome = yamlMap['definitions']?[definitionType]?['appHome'];
      if (appHome == null) {
        throw ConfigError(
            "appHome is required. This is the home screen's name or ID for your App");
      }
      String? i18nPath = yamlMap['definitions']?[definitionType]?['i18nPath'];
      if (i18nPath == null) {
        throw ConfigError(
            "i18nPath is required. If you don't have any changes, just leave the default as-is.");
      }
      bool cacheEnabled =
          yamlMap['definitions']?[definitionType]?['enableCache'] == true;
      i18nProps.path = i18nPath;
      String fullPath = concatDirectory(path, appId);
      return (definitionType == 'local')
          ? LocalDefinitionProvider(fullPath, appHome, i18nProps)
          : RemoteDefinitionProvider(
              fullPath, appHome, cacheEnabled, i18nProps);
    } else {
      throw ConfigError(
          "Definitions needed to be defined as 'local', 'remote', or 'ensemble'");
    }
  }

  // TODO: use Provider to inject Account/DefinitionProvider in for the entire App
  Account? getAccount() {
    return _config?.account;
  }

  EnsembleConfig? getConfig() {
    return _config;
  }

  /// Navigate to an Ensemble App as configured in ensemble-config.yaml
  /// [screenId] / [screenName] - navigate to the screen if specified, otherwise to the App's home
  /// [asModal] - shows the App in a regular or modal screen
  /// [pageArgs] - Key/Value pairs to send to the screen if it takes input parameters
  void navigateApp(
    BuildContext context, {
    String? screenId,
    String? screenName,
    bool? asModal,
    Map<String, dynamic>? pageArgs,
  }) {
    PageType pageType = asModal == true ? PageType.modal : PageType.regular;

    Widget screenWidget = EnsembleApp(
        screenPayload: ScreenPayload(
            screenId: screenId,
            screenName: screenName,
            pageType: pageType,
            arguments: pageArgs));

    Map<String, dynamic>? transition =
        Theme.of(context).extension<EnsembleThemeExtension>()?.transitions;

    final _pageType = pageType == PageType.modal ? 'modal' : 'page';

    final transitionType =
        PageTransitionTypeX.fromString(transition?[_pageType]?['type']);
    final alignment = Utils.getAlignment(transition?[_pageType]?['alignment']);
    final duration =
        Utils.getInt(transition?[_pageType]?['duration'], fallback: 250);

    Navigator.push(
      context,
      ScreenController().getScreenBuilder(
        screenWidget,
        pageType: pageType,
        transitionType: transitionType,
        alignment: alignment,
        duration: duration,
      ),
    );
  }

  /// concat into the format root/folder/
  @visibleForTesting
  String concatDirectory(String root, String folder) {
    // strip out all slashes
    RegExp slashPattern = RegExp(r'^[\/]?(.+?)[\/]?$');

    return slashPattern.firstMatch(root)!.group(1)! +
        '/' +
        slashPattern.firstMatch(folder)!.group(1)! +
        '/';
  }

  // TODO: rework the concept of root scope
  RootScope? _rootScope;
  RootScope rootScope() {
    _rootScope ??= RootScope();
    return _rootScope!;
  }
}

class RootScope {
  // Root scope supports 1 timer only
  EnsembleTimer? rootTimer;
}

/// configuration for an App, derived from the YAML + API calls
class EnsembleConfig {
  EnsembleConfig(
      {required this.definitionProvider,
      this.account,
      this.envOverrides,
      this.appBundle});
  final DefinitionProvider definitionProvider;
  Account? account;

  // environment variable overrides
  Map<String, dynamic>? envOverrides;

  // this can be fetched via definitionProvider, but we'll give the option
  // to pass it in via the constructor, as Ensemble can be pre-load
  // with initialize() which does all the async processing.
  AppBundle? appBundle;

  /// Update the appBundle using our definitionProvider
  /// return the same EnsembleConfig once completed for convenience
  Future<EnsembleConfig> updateAppBundle({bool bypassCache = false}) async {
    appBundle = await definitionProvider.getAppBundle(bypassCache: bypassCache);
    return this;
  }

  /// pass our custom theme from the appBundle and build the App Theme
  ThemeData getAppTheme() {
    return ThemeManager().getAppTheme(appBundle?.theme);
  }

  /// retrieve the global widgets/codes/APIs
  YamlMap? getResources() {
    return appBundle?.resources;
  }

  FlutterI18nDelegate getI18NDelegate() {
    return definitionProvider.getI18NDelegate();
  }
}

class I18nProps {
  String defaultLocale;
  String fallbackLocale;
  bool useCountryCode;
  late String path;
  I18nProps(this.defaultLocale, this.fallbackLocale, this.useCountryCode);
}

class AppBundle {
  AppBundle({this.theme, this.resources});

  YamlMap? theme; // theme
  YamlMap? resources; // globally available widgets/codes/APIs
}

/// store the App's account info (e.g. access token for maps)
class Account {
  Account({this.mapAccessToken});
  String? mapAccessToken;
}

/// user configuration for the App
class UserAppConfig {
  UserAppConfig({this.baseUrl, this.useBrowserUrl, this.envVariables});

  String? baseUrl;
  bool? useBrowserUrl;
  Map<String, dynamic>? envVariables;
}
