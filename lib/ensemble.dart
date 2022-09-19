import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:yaml/yaml.dart';

/// Singleton Controller
class Ensemble {
  static final Ensemble _instance = Ensemble._internal();
  Ensemble._internal();
  factory Ensemble() {
    return _instance;
  }

  /// the configuration required to run an App
  EnsembleConfig? _config;

  /// init an App from config file
  /// This can be called multiple times but only initialized once.
  /// For integrating with existing Flutter apps, this function can
  /// be called to pre-initialize for faster loading of Ensemble app later.
  Future<EnsembleConfig> initialize() async {
    // only initialize once
    if (_config != null) {
      return Future<EnsembleConfig>.value(_config);
    }

    final yamlString = await rootBundle.loadString(
        'ensemble/ensemble-config.yaml');
    final YamlMap yamlMap = loadYaml(yamlString);

    DefinitionProvider definitionProvider = _getDefinitionProvider(yamlMap);
    _config = EnsembleConfig(
      definitionProvider: definitionProvider,
      appBundle: await definitionProvider.getAppBundle(),
      account: Account(mapAccessToken: yamlMap['accounts']?['maps']?['mapbox_access_token'])
    );
    return _config!;
  }

  /// return the definition provider (local, remote, or Ensemble)
  DefinitionProvider _getDefinitionProvider(YamlMap yamlMap) {
    // locale
    I18nProps i18nProps = I18nProps(
      yamlMap['i18n']?['defaultLocale'] ?? '',
      yamlMap['i18n']?['fallbackLocale'] ?? 'en',
      yamlMap['i18n']?['useCountryCode'] ?? false
    );

    // Ensemble-powered apps
    String? definitionType = yamlMap['definitions']?['from'];
    if (definitionType == 'ensemble') {
      String? path = yamlMap['definitions']?['ensemble']?['path'];
      if (path == null || !path.startsWith('https')) {
        throw ConfigError('Invalid URL to Ensemble server. The original value should not be changed');
      }
      String? appId = yamlMap['definitions']?['ensemble']?['appId'];
      if (appId == null) {
        throw ConfigError(
            "appId is required. Your App Key can be found on "
                "Ensemble Studio under each application");
      }
      String? i18nPath = yamlMap['definitions']?['ensemble']?['i18nPath'];
      if (i18nPath == null) {
        throw ConfigError(
            "i18nPath is required. If you don't have any changes, just leave the default as-is.");
      }
      bool cacheEnabled = yamlMap['definitions']?['ensemble']?['enableCache'] == true;
      i18nProps.path = i18nPath;
      return EnsembleDefinitionProvider(path, appId, cacheEnabled, i18nProps);
    }
    // local/remote Apps
    else if (definitionType == 'local' || definitionType == 'remote'){
      String? path = yamlMap['definitions']?[definitionType]?['path'];
      if (path == null) {
        throw ConfigError(
            "Path to the root definition directory is required.");
      }
      String? appId = yamlMap['definitions']?[definitionType]?['appId'];
      if (appId == null) {
        throw ConfigError(
            "appId is required. This is your App's directory under the root path.");
      }
      String? appHome = yamlMap['definitions']?[definitionType]?['appHome'];
      if (appHome == null) {
        throw ConfigError(
            "appHome is required. This is the home screen's name or ID for your App"
        );
      }
      String? i18nPath = yamlMap['definitions']?[definitionType]?['i18nPath'];
      if (i18nPath == null) {
        throw ConfigError(
            "i18nPath is required. If you don't have any changes, just leave the default as-is.");
      }
      bool cacheEnabled = yamlMap['definitions']?[definitionType]?['enableCache'] == true;
      i18nProps.path = i18nPath;
      String fullPath = concatDirectory(path, appId);
      return (definitionType == 'local') ?
        LocalDefinitionProvider(fullPath, appHome, i18nProps) :
        RemoteDefinitionProvider(fullPath, appHome, cacheEnabled, i18nProps);

    } else {
      throw ConfigError(
          "Definitions needed to be defined as 'local', 'remote', or 'ensemble'");
    }
  }


  // TODO: use Provider to inject these in for the entire App
  Account? getAccount() {
    return _config?.account;
  }







  //// Legacy stuff - to be removed

  static final DeviceInfoPlugin _deviceInfoPlugin = DeviceInfoPlugin();
  late DeviceInfo deviceInfo;
  /// initialize device info
  void initDeviceInfo(BuildContext context) async {
    DevicePlatform? platform;
    WebBrowserInfo? browserInfo;
    try {
      if (kIsWeb) {
        platform = DevicePlatform.web;
        browserInfo = await _deviceInfoPlugin.webBrowserInfo;
      } else {
        if (Platform.isAndroid) {
          platform = DevicePlatform.android;

        } else if (Platform.isIOS) {
          platform = DevicePlatform.ios;

        } else if (Platform.isMacOS) {
          platform = DevicePlatform.macos;

        } else if (Platform.isWindows) {
          platform = DevicePlatform.windows;
        }
      }
    } on PlatformException {
      log("Error getting device info");
    }

    MediaQueryData mediaQueryData = MediaQuery.of(context);
    deviceInfo = DeviceInfo(
        platform ?? DevicePlatform.other,
        size: mediaQueryData.size,
        safeAreaSize: SafeAreaSize(mediaQueryData.padding.top.toInt(), mediaQueryData.padding.bottom.toInt()),
        browserInfo: browserInfo);
  }

  /// Navigate to another screen
  /// [screenName] - navigate to screen if specified, otherwise to appHome
  PageRouteBuilder navigateApp(BuildContext context, {
    String? screenName,
    bool? asModal,
    Map<String, dynamic>? pageArgs,
  }) {
    PageRouteBuilder route = getAppRoute(
        screenName: screenName,
        asModal: asModal,
        pageArgs: pageArgs);
    Navigator.push(context, route);

    return route;
  }


  /// return Ensemble App's PageRoute, suitable to be embedded as a PageRoute
  /// [screenName] optional screen name or id to navigate to. Otherwise use the appHome
  PageRouteBuilder getAppRoute({
    String? screenName,
    bool? asModal,
    Map<String, dynamic>? pageArgs
  }) {
    Widget newScreen = Screen(
      appProvider: AppProvider(definitionProvider: _config!.definitionProvider),
      screenPayload: ScreenPayload(
        screenId: screenName,
        arguments: pageArgs,
        type: asModal == true ? PageType.modal : PageType.regular
      ),
    );

    if (asModal == true) {
      return EnsembleModalPageRouteBuilder(screenWidget: newScreen);
    } else {
      return EnsemblePageRouteBuilder(screenWidget: newScreen);
    }
  }

  /// concat into the format root/folder/
  @visibleForTesting
  String concatDirectory(String root, String folder) {
    // strip out all slashes
    RegExp slashPattern = RegExp(r'^[\/]?(.+?)[\/]?$');

    return slashPattern.firstMatch(root)!.group(1)! + '/' +
        slashPattern.firstMatch(folder)!.group(1)! + '/';
  }

}



/// configuration for an App, derived from the YAML + API calls
class EnsembleConfig {
  EnsembleConfig({
    required this.definitionProvider,
    this.account,
    this.appBundle
  });
  final DefinitionProvider definitionProvider;
  Account? account;

  // this can be fetched via definitionProvider, but we'll give the option
  // to pass it in via the constructor, as Ensemble can be pre-load
  // with initialize() which does all the async processing.
  AppBundle? appBundle;

  /// Update the appBundle using our definitionProvider
  /// return the same EnsembleConfig once completed for convenience
  Future<EnsembleConfig> updateAppBundle() async {
    appBundle = await definitionProvider.getAppBundle();
    return this;
  }

  /// pass our custom theme from the appBundle and build the App Theme
  ThemeData getAppTheme() {
    return EnsembleTheme.getAppTheme(appBundle?.theme);
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
  AppBundle({this.theme});

  YamlMap? theme;
}
/// store the App's account info (e.g. access token for maps)
class Account {
  Account({this.mapAccessToken});
  String? mapAccessToken;
}

