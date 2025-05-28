import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/firebase_options.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/firebase_functions/firebase_functions_api_provider.dart';
import 'package:ensemble/framework/assets_service.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/definition_providers/ensemble_provider.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event/change_locale_events.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/app_info.dart';
import 'package:ensemble/framework/logging/console_log_provider.dart';
import 'package:ensemble/framework/logging/log_manager.dart';
import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:ensemble/framework/ensemble_config_service.dart';
import 'package:ensemble/framework/route_observer.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/secrets.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/stub/oauth_controller.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/UserLocale.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_i18n/flutter_i18n_delegate.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:get_it/get_it.dart';
import 'package:yaml/yaml.dart';
import 'package:firebase_core/firebase_core.dart';
import 'html_shim.dart' if (dart.library.html) 'dart:html' show window;
import 'package:jsparser/jsparser.dart';
import 'framework/theme/theme_loader.dart';
import 'layout/ensemble_page_route.dart';

typedef CustomBuilder = Widget Function(
    BuildContext context, Map<String, dynamic>? args);

abstract class WithEnsemble {}

/// Singleton Controller
class Ensemble extends WithEnsemble with EnsembleRouteObserver {
  static final Ensemble _instance = Ensemble._internal();

  Ensemble._internal() {
    // register listeners to listen to route changes
    initializeRouteObservers();
  }

  factory Ensemble() {
    return _instance;
  }

  Map<String, Function> externalMethods = {};
  Map<String, CustomBuilder> externalWidgets = {};

  void setExternalWidgets(Map<String, CustomBuilder> widgets) =>
      externalWidgets = widgets;

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
    // Initialize the config service to get `ensemble-config.yaml` file to access the configuration using static property as `EnsembleConfigService.config`
    if (!EnsembleConfigService.isInitialized) {
      await EnsembleConfigService.initialize();
    }

    // get the config YAML
    final YamlMap yamlMap = EnsembleConfigService.config;

    Account account = Account.fromYaml(yamlMap['accounts']);
    dynamic analyticsConfig = yamlMap['analytics'];
    if (analyticsConfig != null && analyticsConfig is Map) {
      String? appId = getAppId(yamlMap);
      if (analyticsConfig['enabled'] == true) {
        await initializeAnalyticsProvider(
            yamlMap['accounts'], analyticsConfig["provider"],
            appId: appId);
      }
      if (analyticsConfig['enableConsoleLogs'] == true) {
        initializeConsoleLogProvider(appId);
      }
    }
    // init Firebase
    if (yamlMap['definitions']?['from'] == 'ensemble') {
      // These are not secrets so OK to include here.
      // https://firebase.google.com/docs/projects/api-keys#api-keys-for-firebase-are-different
      ensembleFirebaseApp = await Firebase.initializeApp(
        name: getFirebaseName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    // environment variable overrides
    Map<String, dynamic>? envOverrides;
    dynamic env = yamlMap['environmentVariables'];
    if (env is YamlMap) {
      envOverrides = {};
      env.forEach((key, value) => envOverrides![key.toString()] = value);
    }
    // Read environmental variables from config/appConfig.json
    try {
      dynamic path = yamlMap["definitions"]?['local']?["path"];
      final configString =
          await rootBundle.loadString('${path}/config/appConfig.json');
      final Map<String, dynamic> configMap = json.decode(configString);
      // Loop through the envVariables from appConfig.json file and add them to the envOverrides
      if (configMap["envVariables"] != null) {
        // Loop through the envVariables from appConfig.json file and add them to the envOverrides
        configMap["envVariables"].forEach((key, value) {
          envOverrides![key] = value;
        });
      }
    } catch (e) {
      debugPrint("appConfig.json file doesn't exist");
    }

    DefinitionProvider definitionProvider = DefinitionProvider.from(yamlMap);
    _config = EnsembleConfig(
        definitionProvider: await definitionProvider.init(),
        appBundle: await definitionProvider.getAppBundle(),
        account: account,
        services: Services.fromYaml(yamlMap['services']),
        signInServices: SignInServices.fromYaml(yamlMap['services']),
        envOverrides: envOverrides);
    // Initializing Local Assets Service to store available local assets names
    if (!LocalAssetsService.isInitialized) {
      await LocalAssetsService.initialize(
          _instance
              .getConfig()
              ?.definitionProvider
              .getAppConfig()
              ?.envVariables,
          yamlMap);
    }
    AppInfo().initPackageInfo(_config);
    await initializeAPIProviders(_config!);
    return _config!;
  }

  String? getAppId(YamlMap yamlMap) {
    return yamlMap['definitions']?['ensemble']?['appId'];
  }

  //configure firebase if it has been configured in the config
  static Future<void> initializeAPIProviders(EnsembleConfig config) async {
    Map<String, APIProvider> providers = {};
    //from the config.definitionProvider.getAppConfig() get the environmentVariables
    //check if there is an enviroment variable named api_providers
    //if yes, it is a comma separated list of api providers
    //for each item in the list, append _config to it and search for its config in the environmentVariables
    //if found, initialize the provider with the config
    //if not found, initialize the provider with an empty map
    UserAppConfig? appConfig = config.definitionProvider.getAppConfig();
    if (appConfig != null) {
      String? apiProviders = appConfig.envVariables?['api_providers'];
      if (apiProviders != null) {
        List<String> providerList = apiProviders.split(',');
        for (String provider in providerList) {
          String providerConfig = '${provider}_config';
          Map<String, dynamic> providerConfigMap = {};
          if (appConfig.envVariables?[providerConfig] != null) {
            try {
              providerConfigMap =
                  json.decode(appConfig.envVariables?[providerConfig]);
            } catch (e) {
              print('Error decoding provider config for $provider');
            }
          } else if (providerConfig == 'firestore_config') {
            if (appConfig.envVariables?['firebase_config'] != null) {
              providerConfigMap =
                  json.decode(appConfig.envVariables?['firebase_config']);
            }
          }
          APIProvider? apiProvider = APIProviders.initProvider(provider);
          if (apiProvider != null) {
            await apiProvider.init(
                config.definitionProvider is EnsembleDefinitionProvider
                    ? (config.definitionProvider as EnsembleDefinitionProvider)
                        .appId
                    : generateRandomString(10),
                providerConfigMap);
            providers[provider] = apiProvider;
          }
        }
      }
    }
    if (appConfig?.envVariables?['firebase_app_check'] == 'true') {
      //Check if Firebase Functions Provider is initialized
      if (FirebaseFunctionsAPIProvider.getFirebaseAppContext() == null) {
        await FirebaseFunctionsAPIProvider().init(
            config.definitionProvider is EnsembleDefinitionProvider
                ? (config.definitionProvider as EnsembleDefinitionProvider)
                    .appId
                : generateRandomString(10),
            json.decode(appConfig?.envVariables?['firebase_config']));
      }
      await FirebaseFunctionsAPIProvider.initializeFirebaseAppCheck();
    }
    config.apiProviders = providers;
  }

  static String generateRandomString(int length) {
    const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    math.Random random = math.Random();

    return List.generate(length, (index) => chars[random.nextInt(chars.length)])
        .join('');
  }

  void initializeConsoleLogProvider(String? appId) {
    LogProvider provider = ConsoleLogProvider()..init(ensembleAppId: appId);
    LogManager().addProviderForAllLevels(LogType.appAnalytics, provider);
  }

  Future<void> initializeAnalyticsProvider(
      YamlMap? accounts, String? analyticsProvider,
      {String? appId}) async {
    if (analyticsProvider != null) {
      LogProvider provider = GetIt.instance<LogProvider>();
      await provider.init(
          options: accounts?[analyticsProvider], ensembleAppId: appId);
      LogManager().addProviderForAllLevels(LogType.appAnalytics, provider);
      print("$analyticsProvider analytics provider initialized");
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

  // users can force a specific locale while running their App. This should
  // essentially override the App's forcedLocale, which override the system-detected locale.
  void setLocale(Locale locale) {
    AppEventBus().eventBus.fire(SetLocaleEvent(locale));
  }

  void clearLocale() {
    AppEventBus().eventBus.fire(ClearLocaleEvent());
  }

  Locale? getLocale() => locale;

  /**
   * The current locale the App is running on. This is the source of truth.
   *
   * Note that there are numerous ways to update the locale (setLocale(),
   * clearLocale(), ensemble config, pass into EnsembleApp(), ... None of these
   * are guaranteed to be accepted until the App resolves the locale.
   * The App will then set this final locale.
   *
   * DO NOT update this variable from outside. Ensemble will automatically populate this.
   */
  Locale? locale;

  List? getSupportedLanguages(BuildContext context) {
    List<String>? languageCodes =
        _config?.definitionProvider.getSupportedLanguages();
    if (languageCodes != null) {
      var localeNames = LocaleNames.of(Utils.globalAppKey.currentContext!);
      return languageCodes
          .map((languageCode) => {
                "languageCode": languageCode,
                // the language name based on the current context (fr is French (in English) or Francés (in Spanish))
                // Note that this maybe null if the LocaleNamesLocalizationsDelegate is not loaded, in which case fallback to nativeName
                "name": localeNames?.nameOf(languageCode) ??
                    LocaleNamesLocalizationsDelegate
                        .nativeLocaleNames[languageCode] ??
                    'Unknown',
                // the language in their native name (fr is Français and en is English). These are always the same regardless of the current language.
                "nativeName": LocaleNamesLocalizationsDelegate
                        .nativeLocaleNames[languageCode] ??
                    'Unknown'
              })
          .toList();
    }
    return null;
  }

  Object? getSelectedLanguage() {
    UserLocale? userLocale = UserLocale.from(Ensemble().getLocale());
    // Check if userLocale is null before accessing languageCode
    if (userLocale != null) {
      String languageCode = userLocale.languageCode;
      var localeNames = LocaleNames.of(Utils.globalAppKey.currentContext!);
      return {
        "languageCode": languageCode,
        // the language name based on the current context (fr is French (in English) or Francés (in Spanish))
        // Note that this maybe null if the LocaleNamesLocalizationsDelegate is not loaded, in which case fallback to nativeName
        "name": localeNames?.nameOf(languageCode) ??
            LocaleNamesLocalizationsDelegate.nativeLocaleNames[languageCode] ??
            'Unknown',
        // the language in their native name (fr is Français and en is English). These are always the same regardless of the current language.
        "nativeName":
            LocaleNamesLocalizationsDelegate.nativeLocaleNames[languageCode] ??
                'Unknown'
      };
    }
    return null;
  }

  void notifyAppLifecycleStateChanged(AppLifecycleState state) {
    _config?.definitionProvider.onAppLifecycleStateChanged(state);
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
      this.appBundle,
      this.apiProviders});

  final DefinitionProvider definitionProvider;
  Account? account;
  Services? services;
  SignInServices? signInServices;
  Map<String, APIProvider>? apiProviders;

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

  bool hasLegacyCustomAppTheme() {
    return ThemeManager().hasLegacyCustomAppTheme(appBundle?.theme);
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

  ParsedCode? getGlobalfunction(String library) {
    Map? globals = getResources();

    final scripts = globals?[ResourceArtifactEntry.Scripts.name];
    if (scripts is! Map) return null;
    if (!scripts.containsKey(library)) return null;

    final libraryCode = scripts[library];
    final code =
        ParsedCode(library, libraryCode, JSInterpreter.parseCode(libraryCode));
    return code;
  }

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

  FlutterI18nDelegate? getI18NDelegate({Locale? forcedLocale}) {
    return definitionProvider.getI18NDelegate(forcedLocale: forcedLocale);
  }
}

class ParsedCode {
  String libraryName;
  String code;
  Program program;

  ParsedCode(this.libraryName, this.code, this.program);
}

class I18nProps {
  String path;
  List<String>? supportedLanguages;
  String? fallbackLanguage;

  I18nProps(this.path, {this.supportedLanguages, this.fallbackLanguage});
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
      firebaseConfig = FirebaseConfig.fromMap(input['firebase']);
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

  factory FirebaseConfig.fromMap(dynamic input) {
    FirebaseOptions? iOSConfig;
    FirebaseOptions? androidConfig;
    FirebaseOptions? webConfig;

    try {
      if (input is Map) {
        Map<String, dynamic> lowercaseInput = input
            .map((key, value) => MapEntry(key.toString().toLowerCase(), value));
        if (lowercaseInput['ios'] != null) {
          iOSConfig = _getPlatformConfig(lowercaseInput['ios']);
        }
        if (lowercaseInput['android'] != null) {
          androidConfig = _getPlatformConfig(lowercaseInput['android']);
        }
        if (lowercaseInput['web'] != null) {
          webConfig = _getPlatformConfig(lowercaseInput['web']);
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
        projectId: entry['projectId'],
        authDomain: entry['authDomain'],
        storageBucket: entry['storageBucket'],
        measurementId: entry['measurementId']);
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
