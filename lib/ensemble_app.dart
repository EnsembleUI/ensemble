import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

/// use this as the root widget for Ensemble
class EnsembleApp extends StatefulWidget {
  const EnsembleApp({
    super.key,
    this.screenPayload,
    this.ensembleConfig
  });

  final ScreenPayload? screenPayload;
  final EnsembleConfig? ensembleConfig;

  @override
  State<StatefulWidget> createState() => EnsembleAppState();

}

class EnsembleAppState extends State<EnsembleApp> {

  /// initialize our App with the the passed in config or
  /// read from our ensemble-config file.
  Future<EnsembleConfig> initApp() async {
    // use the config if passed in
    if (widget.ensembleConfig != null) {
      // set the Ensemble config
      Ensemble().setEnsembleConfig(widget.ensembleConfig!);

      // if appBundle is not passed in, fetch it now
      if (widget.ensembleConfig!.appBundle == null) {
        return widget.ensembleConfig!.updateAppBundle();
      }
      return Future<EnsembleConfig>.value(widget.ensembleConfig);
    }
    // else init from config file
    else {
      return Ensemble().initialize();
    }
  }

  late Future<EnsembleConfig> config;
  @override
  void initState() {
    super.initState();
    config = initApp();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: config,
      builder: ((context, snapshot) {

        if (snapshot.hasError) {
          return _appPlaceholderWrapper(
              widget: ErrorScreen(LanguageError(
                "Error loading configuration",
                detailError: snapshot.error.toString()
              )
            )
          );
        }

        // at this point we don't yet have the theme. It's best to have
        // a blank screen to prevent any background color changing while
        // the app is loading
        if (!snapshot.hasData) {
          // blank loading screen
          return _appPlaceholderWrapper();
        }

        return renderApp(snapshot.data as EnsembleConfig);
      })
    );
  }

  Widget renderApp(EnsembleConfig config) {
    log("EnsembleApp build() - $hashCode");
    return MaterialApp(
      navigatorKey: Utils.globalAppKey,
      theme: config.getAppTheme(),
      localizationsDelegates: [
        config.getI18NDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate
      ],
      home: Scaffold(
        body: Screen(
          appProvider: AppProvider(definitionProvider: config.definitionProvider),
          screenPayload: widget.screenPayload,
        ),
      ),
      builder: (context, widget) {
        _setCustomErrorWidget();

        Ensemble().initDeviceInfo(context);

        return FlutterI18n.rootAppBuilder().call(context, widget);
      },
    );
  }

  void _setCustomErrorWidget() {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return ErrorScreen(errorDetails);
    };
  }

  /// we are at the root here. Error/Spinner widgets need
  /// to be wrapped inside MaterialApp
  Widget _appPlaceholderWrapper({Widget? widget, Color? loadingBackgroundColor}) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: loadingBackgroundColor,
        body: widget
      )
    );
  }



}