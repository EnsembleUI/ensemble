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
class EnsembleApp extends StatelessWidget {
  const EnsembleApp({
    super.key,
    this.screenPayload,
    this.ensembleConfig
  });
  final ScreenPayload? screenPayload;
  final EnsembleConfig? ensembleConfig;

  /// initialize our App with the the passed in config or
  /// read from our ensemble-config file.
  Future<EnsembleConfig> initApp() async {
    // use the config if passed in
    if (ensembleConfig != null) {
      // if appBundle is not passed in, fetch it now
      if (ensembleConfig!.appBundle == null) {
        return ensembleConfig!.updateAppBundle();
      }
      return Future<EnsembleConfig>.value(ensembleConfig);
    }
    // else init from config file
    else {
      return Ensemble().initialize();
    }
  }

  @override
  Widget build(BuildContext context) {
    log("EnsembleApp build() - $hashCode");
    return FutureBuilder(
      future: initApp(),
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

        if (!snapshot.hasData) {
          // blank loading screen
          return _appPlaceholderWrapper();
        }

        return renderApp(snapshot.data as EnsembleConfig);
      })
    );
  }

  Widget renderApp(EnsembleConfig config) {
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
          screenPayload: screenPayload,
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