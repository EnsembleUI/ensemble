import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;

import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/ensemble_provider.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/app_info.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/secrets.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/provider.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:yaml/yaml.dart';
import 'package:firebase_core/firebase_core.dart';
import 'html_shim.dart' if (dart.library.html) 'dart:html' show window;
import 'package:jsparser/jsparser.dart';
import 'framework/theme/theme_loader.dart';
import 'layout/ensemble_page_route.dart';

typedef CustomBuilder = Widget Function(
    BuildContext context, Map<String, dynamic>? args);

/// Singleton Controller
class Ensemble {
  static final Ensemble _instance = Ensemble._internal();

  Ensemble._internal();

  factory Ensemble() {
    return _instance;
  }

  Map<String, Function> externalMethods = {};

  void setExternalMethods(Map<String, Function> methods) =>
      externalMethods = methods;

  Map<String, CustomBuilder> externalScreenWidgets = {};

  void setExternalScreenWidgets(Map<String, CustomBuilder> widgets) {
    externalScreenWidgets = widgets;
  }

  // TODO: combine push callback and regular callback
  final Set<Function> _pushNotificationCallbacks = {};
  void addPushNotificationCallback({required Function method}) {
    _pushNotificationCallbacks.add(method);
  }

  Set<Function> getPushNotificationCallbacks() => _pushNotificationCallbacks;

  final Set<Function> _afterInitMethods = {};
  void addCallbackAfterInitialization({required Function method}) {
    _afterInitMethods.add(method);
  }

  Set<Function> getCallbacksAfterInitialization() => _afterInitMethods;

  late FirebaseApp ensembleFirebaseApp;
  static final Map<String, dynamic> externalDataContext = {};

  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  /// initialize all the singleton/managers. Note that this function can be
  /// called multiple times since it's being called inside a widget.
  /// The actual code block to initialize the managers is guaranteed to run
  /// at most once.
  Completer<void>? _completer;

  Future<void> initManagers() async {
    // if currently pending or completed, wait till it finishes and do nothing.
    if (_completer != null) {
      return _completer!.future;
    }

    _completer = Completer<void>();
    try {
      // this code block is guaranteed to run at most once
      await StorageManager().init();
      await SecretsStore().initialize();
      Device().initDeviceInfo();
      AppInfo().initPackageInfo(_config);
      _completer!.complete();
    } catch (error) {
      _completer!.completeError(error);
    }
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
    if (kIsWeb) {
      log("Server: ${window.location.protocol}//${window.location.host}${window.location.pathname}");
    }

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
      ensembleFirebaseApp = await Firebase.initializeApp(
          name: getFirebaseName,
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
        account: Account.fromYaml(yamlMap['accounts']),
        services: Services.fromYaml(yamlMap['services']),
        signInServices: SignInServices.fromYaml(yamlMap['services']),
        envOverrides: envOverrides);

    AppInfo().initPackageInfo(_config);
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

  String? get getFirebaseName {
    try {
      return Firebase.apps.isNotEmpty ? 'ensemble' : null;
    } catch (e) {
      /// Firebase flutter web implementation throws error of uninitialized project
      /// When project is no initialized which means we can set ensemble as primary project
      return null;
    }
  }

  // TODO: use Provider to inject Account/DefinitionProvider in for the entire App
  Account? getAccount() {
    return _config?.account;
  }

  Services? getServices() {
    return _config?.services;
  }

  SignInServices? getSignInServices() {
    return _config?.signInServices;
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
    bool isExternal = false,
  }) {
    PageType pageType = asModal == true ? PageType.modal : PageType.regular;

    Widget screenWidget = EnsembleApp(
        screenPayload: ScreenPayload(
            screenId: screenId,
            screenName: screenName,
            pageType: pageType,
            arguments: pageArgs,
            isExternal: isExternal));

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
      this.services,
      this.signInServices,
      this.envOverrides,
      this.appBundle});

  final DefinitionProvider definitionProvider;
  Account? account;
  Services? services;
  SignInServices? signInServices;

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

  /// update Env Variables at any later time wil override the values we
  /// got from our config file
  void updateEnvOverrides(Map<String, dynamic> updatedMap) {
    if (updatedMap.isNotEmpty) {
      (envOverrides ??= {}).addAll(updatedMap);
    }
  }

  /// pass our custom theme from the appBundle and build the App Theme
  ThemeData getAppTheme() {
    return ThemeManager().getAppTheme(appBundle?.theme);
  }

  /// retrieve the global widgets/codes/APIs
  Map? getResources() {
    return appBundle?.resources;
  }

  /* example of code
    ensemble.storage.jslibtest = {name: {first:'apiUtils.first', last: 'apiUtils.last'}};
    var storageName = ensemble.storage.jslibtest;
    var apiUtilsCount = 0;
    function callAPI(name,inputs) {
      apiUtilsCount++;
      console.log('apiUtilsCount='+apiUtilsCount);
      internalCallAPI(name,inputs);
    }
    function internalCallAPI(name,inputs) {
      ensemble.invokeAPI(name,{});
    }
   */
  List<ParsedCode>? processImports(YamlList? imports) {
    if (imports == null) {
      return null;
    }
    Map<String, ParsedCode>? importMap = {};
    Map? globals = getResources();
    globals?[ResourceArtifactEntry.Scripts.name]?.forEach((key, value) {
      if (imports.contains(key)) {
        if (value is String) {
          try {
            importMap[key] =
                ParsedCode(key, value, JSInterpreter.parseCode(value));
          } catch (e) {
            throw 'Error Parsing Code. Invalid code definition for $key. Detailed Message: $e';
          }
        } else if (value is ParsedCode) {
          //it's already parsed so need to parse again
          importMap[key] = value;
        } else {
          throw 'Invalid code definition for $key';
        }
      }
    });
    List<ParsedCode>? importList = [];
    for (var element in imports) {
      if (importMap[element] != null) {
        importList.add(importMap[element]!);
      }
    }
    return importList;
  }

  FlutterI18nDelegate getI18NDelegate() {
    return definitionProvider.getI18NDelegate();
  }
}

class ParsedCode {
  String libraryName;
  String code;
  Program program;

  ParsedCode(this.libraryName, this.code, this.program);
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
  Map? resources; // globally available widgets/codes/APIs
}

/// store the App's account info (e.g. access token for maps)
class Account {
  Account({this.firebaseConfig, this.googleMapsAPIKey});

  FirebaseConfig? firebaseConfig;

  String? googleMapsAPIKey;

  factory Account.fromYaml(dynamic input) {
    FirebaseConfig? firebaseConfig;
    String? googleMapsAPIKey;

    if (input != null && input is Map) {
      firebaseConfig = FirebaseConfig.fromYaml(input['firebase']);
      googleMapsAPIKey = Utils.optionalString(input['googleMaps']?['apiKey']);
    }
    return Account(
        firebaseConfig: firebaseConfig, googleMapsAPIKey: googleMapsAPIKey);
  }
}

class FirebaseConfig {
  FirebaseConfig._({this.iOSConfig, this.androidConfig, this.webConfig});

  FirebaseOptions? iOSConfig;
  FirebaseOptions? androidConfig;
  FirebaseOptions? webConfig;

  factory FirebaseConfig.fromYaml(dynamic input) {
    FirebaseOptions? iOSConfig;
    FirebaseOptions? androidConfig;
    FirebaseOptions? webConfig;

    try {
      if (input is Map) {
        if (input['iOS'] != null) {
          iOSConfig = _getPlatformConfig(input['iOS']);
        }
        if (input['android'] != null) {
          androidConfig = _getPlatformConfig(input['android']);
        }
        if (input['web'] != null) {
          webConfig = _getPlatformConfig(input['web']);
        }
      }
      return FirebaseConfig._(
          iOSConfig: iOSConfig,
          androidConfig: androidConfig,
          webConfig: webConfig);
    } catch (error) {
      throw ConfigError(
          'Invalid Firebase configuration. Please double check your ensemble-config.yaml');
    }
  }

  static FirebaseOptions _getPlatformConfig(dynamic entry) {
    return FirebaseOptions(
        apiKey: entry['apiKey'],
        appId: entry['appId'],
        messagingSenderId: entry['messagingSenderId'].toString(),
        projectId: entry['projectId']);
  }
}

/// for social sign-in and API authorization via OAuth2
class Services {
  Services._({this.oauthCredentials});

  Map<OAuthService, ServiceCredential>? oauthCredentials;

  factory Services.fromYaml(dynamic input) {
    Map<OAuthService, ServiceCredential>? credentials;
    if (input is YamlMap && input['oauth'] is YamlMap) {
      (input['oauth'] as YamlMap).forEach((key, value) {
        var serviceName = OAuthService.values.from(key);
        if (serviceName != null && value is YamlMap) {
          (credentials ??= {})[serviceName] = ServiceCredential.fromYaml(value);
        }
      });
    }
    return Services._(oauthCredentials: credentials);
  }

  ServiceCredential? getServiceCredential(OAuthService service) =>
      oauthCredentials?[service];
}

class ServiceCredential {
  ServiceCredential._({this.config, this.credentialMap});

  Map<String, dynamic>? config;
  Map<DevicePlatform, OAuthCredential>? credentialMap;

  factory ServiceCredential.fromYaml(YamlMap input) {
    Map<String, dynamic>? config;
    Map<DevicePlatform, OAuthCredential>? credentialMap;
    input.forEach((key, value) {
      // get the config
      if (key == 'config') {
        if (value is YamlMap) {
          (config ??= {}).addAll({...value});
        }
      }
      // intercept Web type to automatically inject the redirectURI in
      else if (key == 'web') {
        if (kIsWeb && value is YamlMap && value['clientId'] is String) {
          var browserUri =
              '${window.location.protocol}//${window.location.host}${window.location.pathname}';
          if (!browserUri.endsWith('/')) {
            browserUri += '/';
          }
          (credentialMap ??= {})[DevicePlatform.web] = OAuthCredential(
              clientId: value['clientId'],
              redirectUri: '${browserUri}oauth.html');
        }
      }
      // get credential map
      else {
        var platform = DevicePlatform.values.from(key);
        if (platform != null &&
            value is YamlMap &&
            value['clientId'] is String &&
            value['redirectUri'] is String) {
          (credentialMap ??= {})[platform] = OAuthCredential(
              clientId: value['clientId'], redirectUri: value['redirectUri']);
        }
      }
    });
    return ServiceCredential._(config: config, credentialMap: credentialMap);
  }

  /// return the credential for the current platform
  OAuthCredential? get platformCredential {
    DevicePlatform? platform = Device().platform;
    return platform != null ? (credentialMap?[platform]) : null;
  }
}

class SignInServices {
  SignInServices._({this.serverUri, this.signInCredentials});

  String? serverUri;
  Map<OAuthService, SignInCredential>? signInCredentials;

  factory SignInServices.fromYaml(dynamic input) {
    String? serverUri;
    Map<OAuthService, SignInCredential>? credentials;
    if (input is YamlMap && input['signIn'] is YamlMap) {
      serverUri = input['signIn']['serverUri'];
      if (input['signIn']['providers'] is YamlMap) {
        (input['signIn']['providers'] as YamlMap).forEach((key, value) {
          var provider = OAuthService.values.from(key);
          if (provider != null && value is Map) {
            (credentials ??= {})[provider] = SignInCredential(
                iOSClientId: value['iOSClientId'],
                androidClientId: value['androidClientId'],
                webClientId: value['webClientId'],
                serverClientId: value['serverClientId']);
          }
        });
      }
    }
    return SignInServices._(
        serverUri: serverUri, signInCredentials: credentials);
  }
}

class SignInCredential {
  SignInCredential(
      {this.iOSClientId,
      this.androidClientId,
      this.webClientId,
      this.serverClientId});

  String? iOSClientId;
  String? androidClientId;
  String? webClientId;
  String? serverClientId;
}

/// user configuration for the App
class UserAppConfig {
  UserAppConfig({this.baseUrl, this.useBrowserUrl, this.envVariables});

  String? baseUrl;
  bool? useBrowserUrl;
  Map<String, dynamic>? envVariables;
}
