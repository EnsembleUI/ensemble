import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:ensemble/deep_link_manager.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/app_info.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/config.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event/change_locale_events.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/ios_deep_link_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/upload_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_localized_locales/flutter_localized_locales.dart';
import 'package:workmanager/workmanager.dart';
import 'package:yaml/yaml.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

const String backgroundUploadTask = 'backgroundUploadTask';
const String backgroundBluetoothSubscribeTask = 'backgroundBluetoothSubscribeTask';

const String ensembleMethodChannelName = 'com.ensembleui.host.platform';
GlobalKey<NavigatorState>? externalAppNavigateKey;
ScrollController? externalScrollController;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    switch (task) {
      case backgroundUploadTask:
        if (inputData == null) {
          throw LanguageError('Failed to parse data to upload');
        }
        try {
          final sendPort =
              IsolateNameServer.lookupPortByName(inputData['taskId']);
          final response = await UploadUtils.uploadFiles(
            fieldName: inputData['fieldName'] ?? 'file',
            files: (inputData['files'] as List)
                .map((e) => File.fromJson(json.decode(e)))
                .toList(),
            headers:
                Map<String, String>.from(json.decode(inputData['headers'])),
            method: inputData['method'],
            url: inputData['url'],
            fields: Map<String, String>.from(json.decode(inputData['fields'])),
            showNotification: inputData['showNotification'],
            progressCallback: (progress) {
              if (sendPort == null) return;
              sendPort.send({
                'progress': progress,
                'taskId': inputData['taskId'],
              });
            },
            onError: (error) {
              if (sendPort == null) return;
              sendPort.send(
                  {'error': error.toString(), 'taskId': inputData['taskId']});
            },
            taskId: inputData['taskId'],
          );

          if (sendPort == null || response == null) return response == null;

          sendPort.send({
            'responseBody': response.body,
            'taskId': inputData['taskId'],
            'responseHeaders': response.headers,
          });
        } catch (e) {
          throw LanguageError('Failed to process background upload task');
        }
        break;
      default:
        throw LanguageError('Unknown background task: $task');
    }
    return Future.value(true);
  });
}

/// use this as the root widget for Ensemble
class EnsembleApp extends StatefulWidget {
  EnsembleApp({
    super.key,
    this.screenPayload,
    this.ensembleConfig,
    this.externalMethods,
    this.isPreview = false,
    this.placeholderBackgroundColor,
    this.onAppLoad,
    this.forcedLocale,
    GlobalKey<NavigatorState>? navigatorKey,
    ScrollController? screenScroller,
  }) {
    externalAppNavigateKey = navigatorKey;
    externalScrollController = screenScroller;
  }

  final ScreenPayload? screenPayload;
  final EnsembleConfig? ensembleConfig;
  final bool isPreview;
  final Map<String, Function>? externalMethods;

  // for integration with external Flutter code
  final Function? onAppLoad;

  /// use this as the placeholder background while Ensemble is loading
  final Color? placeholderBackgroundColor;

  /// use this if you want the App to start out with this local
  final Locale? forcedLocale;

  @override
  State<StatefulWidget> createState() => EnsembleAppState();
}

class EnsembleAppState extends State<EnsembleApp> with WidgetsBindingObserver {
  bool notifiedAppLoad = false;
  late Future<EnsembleConfig> config;

  // user can force the locale at runtime using this.
  // Essentially this order: runtimeLocale ?? widget.forcedLocale ?? <system-detected locale>
  Locale? runtimeLocale;

  // our MaterialApp uses this key, so update this if we want to force
  // the entire App to reload (e.g. change Locale at runtime)
  Key? appKey;

  bool _hasInternet = true;
  late final StreamSubscription<List<ConnectivityResult>>
      _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    config = initApp();

    // Initialize connectivity listener.
    _updateConnectivity();
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((_) => _updateConnectivity());

    // Initialize native features.
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      initDeepLink(AppLifecycleState.resumed);
    }
    AppEventBus().eventBus.on<ThemeChangeEvent>().listen((event) {
      setState(() {});
    });

    // selecting a Locale at run time
    AppEventBus().eventBus.on<SetLocaleEvent>().listen((event) async {
      if (runtimeLocale != event.locale) {
        runtimeLocale = event.locale;
        rebuildApp();
      }
    });
    AppEventBus().eventBus.on<ClearLocaleEvent>().listen((event) {
      if (runtimeLocale != null) {
        runtimeLocale = null;
        rebuildApp();
      }
    });
    if (EnvConfig().isTestMode) {
      SemanticsBinding.instance.ensureSemantics();
    }
  }

  /// Check the device’s connectivity and update the state.
  Future<void> _updateConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    final hasInternetNow = result.any((r) => r != ConnectivityResult.none);

    // If connectivity has been restored, reinitialize the app
    if (!_hasInternet && hasInternetNow) {
      setState(() {
        config = initApp();
      });
    }

    setState(() {
      _hasInternet = hasInternetNow;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    Ensemble().notifyAppLifecycleStateChanged(state);
    initDeepLink(state);
  }

  void initDeepLink(AppLifecycleState state) {
    if (!kIsWeb) {
      if (Platform.isIOS) {
        IOSDeepLinkManager().init();
      } else {
        DeepLinkManager().init();
      }
    }
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// initialize our App with the the passed in config or
  /// read from our ensemble-config file.
  Future<EnsembleConfig> initApp() async {
    await Ensemble().initManagers();
    StorageManager().setIsPreview(widget.isPreview);

    if (widget.externalMethods != null) {
      Ensemble().setExternalMethods(widget.externalMethods!);
    }

    // use the config if passed in
    if (widget.ensembleConfig != null) {
      // set the Ensemble config
      Ensemble().setEnsembleConfig(widget.ensembleConfig!);

      // if appBundle is not passed in, fetch it now
      if (widget.ensembleConfig!.appBundle == null) {
        return widget.ensembleConfig!.updateAppBundle();
      }
      await Ensemble.initializeAPIProviders(widget.ensembleConfig!);
      return Future<EnsembleConfig>.value(widget.ensembleConfig);
    }
    // else init from config file
    else {
      return Ensemble().initialize();
    }
  }

  /**
   * Completely rebuild our widget tree by changing the key.
   * This is often unnecessary unless for something like changing Locale
   * at runtime where a complete rebuild is needed.
   */
  void rebuildApp() {
    setState(() {
      appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: config,
        builder: ((context, snapshot) {
          if (snapshot.hasError) {
            return _appPlaceholderWrapper(
                placeholderWidget: ErrorScreen(LanguageError(
                    "Error loading configuration",
                    detailedError: snapshot.error.toString())));
          }

          // at this point we don't yet have the theme. It's best to have
          // a blank screen to prevent any background color changing while
          // the app is loading
          if (!snapshot.hasData) {
            // blank loading screen
            return _appPlaceholderWrapper(
                placeholderBackgroundColor: widget.placeholderBackgroundColor);
          }

          return renderApp(snapshot.data as EnsembleConfig);
        }));
  }

  void configureThemes(YamlMap doc, AppConfig config) {
    if (EnsembleThemeManager().initialized) {
      return;
    }
    Map<String, YamlMap> themes = {};
    String? defaultTheme;
    String? savedTheme = config.getSavedTheme();
    bool foundSelectedTheme = false;
    if (doc["Themes"] != null) {
      for (var theme in doc['Themes']) {
        String? themeName;
        if (theme is YamlMap) {
          themeName = theme.keys.first;
          YamlMap? themeMap = theme[themeName];
          if (themeMap != null) {
            if (themeMap.containsKey('default') &&
                themeMap['default'] == true) {
              defaultTheme = themeName;
            }
          }
        } else {
          themeName = theme;
        }
        themes[themeName!] = doc[themeName] ?? YamlMap();
        if (savedTheme != null &&
            themeName == savedTheme &&
            !foundSelectedTheme) {
          foundSelectedTheme = true;
        }
      }
    }
    if (themes.isNotEmpty && defaultTheme == null) {
      defaultTheme = themes.keys.first;
    }
    defaultTheme ??= EnsembleThemeManager.defaultThemeWhenNoneSpecified;
    if (themes.isEmpty) {
      //no themes defined, we'll assume eveyrthing is in the root
      themes[defaultTheme] = doc;
    }
    if (foundSelectedTheme && savedTheme != null) {
      defaultTheme = savedTheme;
    }
    EnsembleThemeManager().init(context, themes, defaultTheme, localeThemes: doc["LocaleThemes"]);
  }

  Locale? resolveLocale(Locale? systemLocale,
      {DefinitionProvider? definitionProvider}) {
    // run sanity check on locale passed in from the outside
    Locale? maybeLocale = runtimeLocale ??
        widget.forcedLocale ??
        definitionProvider?.initialForcedLocale;
    if (maybeLocale != null &&
        kMaterialSupportedLanguages.contains(maybeLocale.languageCode)) {
      // the country code can still be invalid. How do we check validity?
      return maybeLocale;
    }
    return systemLocale;
  }

  Widget renderApp(EnsembleConfig config) {
    //even of there is no theme passed in, we still call init as thememanager would initialize with default styles
    if (config.appBundle?.theme?['cssStyling'] != false) {
      YamlMap? doc = config.appBundle?.theme;
      if (doc != null) {
        configureThemes(doc, AppConfig(context, AppInfo().appId));
      }
    }
    EnsembleThemeManager().setCurrentLocale(Ensemble().locale?.languageCode,notifyListeners: false);
    // notify external app once of EnsembleApp loading status
    if (widget.onAppLoad != null && !notifiedAppLoad) {
      widget.onAppLoad!.call();
      notifiedAppLoad = true;
    }

    Widget screen = Screen(
      appProvider: AppProvider(definitionProvider: config.definitionProvider),
      screenPayload: widget.screenPayload,
      apiProviders: APIProviders.clone(config.apiProviders ?? {}),
    );
    ThemeData? theme;
    //if we have defined legacy themes at the root level or if thre is no Styles at the root level, we use the app level theme
    if (config.hasLegacyCustomAppTheme() ||
        EnsembleThemeManager().currentTheme()?.appThemeData == null) {
      //backward compatibility in case apps are using the old style of App level theming that is at the root level
      theme = config.getAppTheme();
    } else {
      theme = EnsembleThemeManager().currentTheme()!.appThemeData;
    }

    StorageManager().setIsPreview(widget.isPreview);
    Widget app = MaterialApp(
      key: appKey,
      navigatorObservers: Ensemble().routeObservers,
      debugShowCheckedModeBanner: false,
      navigatorKey: Utils.globalAppKey,
      theme: theme,
      localizationsDelegates: getLocalizationDelegates(config),
      // Note that we either need supportedLocales or this callback.
      // Also note that the placeholder's MaterialApp also has the same
      // requirement even if it is just a placeholder.
      localeResolutionCallback: (systemLocale, _) {
        Ensemble().locale = resolveLocale(systemLocale,
            definitionProvider: config.definitionProvider);
        return Ensemble().locale;
      },
      home: Scaffold(
        // this outer scaffold is where the background image would be (if
        // specified). We do not want it to resize on keyboard popping up.
        // The Page's Scaffold can handle the resizing.
          resizeToAvoidBottomInset: false,
          body: screen),
      useInheritedMediaQuery: widget.isPreview,
      builder: (context, child) => widget.isPreview
          ? DevicePreview.appBuilder(context, child)
          : (child ?? SizedBox.shrink()),
    );

    // adjust for text scaling globally
    var textScale =
        theme!.extension<EnsembleThemeExtension>()?.appTheme?.textScale;
    if (textScale != null) {
      if (textScale.enabled == false) {
        app = MediaQuery.withNoTextScaling(child: app);
      } else if (textScale.minFactor != null || textScale.maxFactor != null) {
        app = MediaQuery.withClampedTextScaling(
            minScaleFactor: textScale.minFactor ?? 0.0,
            maxScaleFactor: textScale.maxFactor ?? double.infinity,
            child: app);
      }
    }

    if (EnsembleThemeManager().currentTheme() != null) {
      app = ThemeProvider(
          theme: EnsembleThemeManager().currentTheme()!, child: app);
    }
    // if ( config.apiProviders != null ) {
    //   app = APIProviders(
    //     providers: config.apiProviders!,
    //     child: app,
    //   );
    // }
    return app;
  }

  // get the list of localization delegates
  List<LocalizationsDelegate> getLocalizationDelegates(EnsembleConfig config) {
    var localizationDelegates = [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate
    ];
    // add translation delegate and country name delegate
    var translationDelegate = config.getI18NDelegate(
        forcedLocale: runtimeLocale ?? widget.forcedLocale);
    if (translationDelegate != null) {
      // we support showing all language names in the native locale (English in English locale, Inglés in Spanish locale)
      // but this means a size-able number of files to load i.e. (# of languages) x (all possible locales).
      // To turn this off add --dart-define=useLocalizedLanguageNames=false
      final bool useLocalizedLanguageNames = const bool.fromEnvironment(
          'useLocalizedLanguageNames',
          defaultValue: true);
      if (useLocalizedLanguageNames) {
        localizationDelegates.insert(0, LocaleNamesLocalizationsDelegate());
      }

      // add translation delegate
      localizationDelegates.insert(0, translationDelegate);
    }
    return localizationDelegates;
  }

  /// we are at the root here. Error/Spinner widgets need
  /// to be wrapped inside MaterialApp
  Widget _appPlaceholderWrapper(
      {Widget? placeholderWidget, Color? placeholderBackgroundColor}) {
    return MaterialApp(
      // even when this is the placeholder and will be replaced later, we still
      // need to either set supportedLocales or handle localeResolutionCallback.
      // Without this the system locale will be incorrect the first time.
      //
      // Also note we pass in the definitionProvider. This is only needed when
      // the EnsembleConfig is passed in directly (without fetching it) and
      // might contain the forcedLocale. For some reason localeResolutionCallback()
      // will only be called once here and not again when the actual App is loaded.
      // An example is when running integration test with another locale.
        localeResolutionCallback: (systemLocale, _) {
          Ensemble().locale = resolveLocale(systemLocale,
              definitionProvider: widget.ensembleConfig?.definitionProvider);
          return Ensemble().locale;
        },
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate
        ],
        home: Scaffold(
            backgroundColor: placeholderBackgroundColor,
            body: placeholderWidget));
  }
}
