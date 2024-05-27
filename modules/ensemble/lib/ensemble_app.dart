import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:ui' as ui;
import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:ensemble/deep_link_manager.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/app_info.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/config.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/secrets.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/ios_deep_link_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/upload_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';
import 'package:yaml/yaml.dart';

const String backgroundUploadTask = 'backgroundUploadTask';
const String ensembleMethodChannelName = 'com.ensembleui.host.platform';
GlobalKey<NavigatorState>? externalAppNavigateKey;

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
          throw LanguageError('Failed to process backgroud upload task');
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
  }) {
    externalAppNavigateKey = navigatorKey;
  }

  final ScreenPayload? screenPayload;
  final EnsembleConfig? ensembleConfig;
  final bool isPreview;
  final Map<String, Function>? externalMethods;

  // for integration with external Flutter code
  final Function? onAppLoad;

  /// use this as the placeholder background while Ensemble is loading
  final Color? placeholderBackgroundColor;

  final Locale? forcedLocale;

  @override
  State<StatefulWidget> createState() => EnsembleAppState();
}

class EnsembleAppState extends State<EnsembleApp> with WidgetsBindingObserver {
  bool notifiedAppLoad = false;
  late Future<EnsembleConfig> config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    config = initApp();
    // Initialize native features.
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
      initDeepLink(AppLifecycleState.resumed);
    }
    AppEventBus().eventBus.on<ThemeChangeEvent>().listen((event) {
      setState(() {});
    });
    if (EnvConfig().isTestMode) {
      SemanticsBinding.instance.ensureSemantics();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: config,
        builder: ((context, snapshot) {
          if (snapshot.hasError) {
            return _appPlaceholderWrapper(
                widget: ErrorScreen(LanguageError("Error loading configuration",
                    detailError: snapshot.error.toString())));
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
    EnsembleThemeManager().init(context, themes, defaultTheme);
  }

  Widget renderApp(EnsembleConfig config) {
    //even of there is no theme passed in, we still call init as thememanager would initialize with default styles
    if (config.appBundle?.theme?['cssStyling'] != false) {
      YamlMap? doc = config.appBundle?.theme;
      if (doc != null) {
        configureThemes(doc, AppConfig(context, AppInfo().appId));
      }
    }
    // notify external app once of EnsembleApp loading status
    if (widget.onAppLoad != null && !notifiedAppLoad) {
      widget.onAppLoad!.call();
      notifiedAppLoad = true;
    }

    StorageManager().setIsPreview(widget.isPreview);
    Widget app = MaterialApp(
      navigatorObservers: [Ensemble.routeObserver],
      debugShowCheckedModeBanner: false,
      navigatorKey: Utils.globalAppKey,
      theme: config.getAppTheme(),
      localizationsDelegates: [
        config.getI18NDelegate(forcedLocale: widget.forcedLocale),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: Scaffold(
        // this outer scaffold is where the background image would be (if
        // specified). We do not want it to resize on keyboard popping up.
        // The Page's Scaffold can handle the resizing.
        resizeToAvoidBottomInset: false,

        body: Screen(
          appProvider:
              AppProvider(definitionProvider: config.definitionProvider),
          screenPayload: widget.screenPayload,
          apiProviders: APIProviders.clone(config.apiProviders ?? {}),
        ),
      ),
      useInheritedMediaQuery: widget.isPreview,
      builder: (context, child) {
        Locale myLocale =
            widget.forcedLocale ?? Localizations.localeOf(context);
        bool isRtl = Bidi.isRtlLanguage(myLocale.languageCode);
        return Directionality(
            textDirection: isRtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
            child: widget.isPreview
                ? DevicePreview.appBuilder(context, child)
                : child ?? SizedBox.shrink());
      },
    );
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

  /// we are at the root here. Error/Spinner widgets need
  /// to be wrapped inside MaterialApp
  Widget _appPlaceholderWrapper(
      {Widget? widget, Color? placeholderBackgroundColor}) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
            backgroundColor: placeholderBackgroundColor, body: widget));
  }
}
