import 'dart:convert';
import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:device_preview/device_preview.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:ensemble/util/upload_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get_storage/get_storage.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';

const String previewConfig = 'preview-config';
const String backgroundUploadTask = 'backgroundUploadTask';

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
            fields: inputData['fields'],
            showNotification: inputData['showNotification'],
            progressCallback: (progress) {
              if (sendPort == null) return;
              sendPort.send({'progress': progress});
            },
            onError: (error) {
              if (sendPort == null) return;
              sendPort.send({'error': error});
            },
          );

          if (sendPort == null || response == null) return response == null;

          sendPort.send({'responseBody': response.body});
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

class EnsemblePreviewConfig {
  EnsemblePreviewConfig(this.isPreview);

  bool isPreview;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnsemblePreviewConfig &&
          runtimeType == other.runtimeType &&
          isPreview == other.isPreview;

  @override
  int get hashCode => isPreview.hashCode;
}

/// use this as the root widget for Ensemble
class EnsembleApp extends StatefulWidget {
  EnsembleApp({
    super.key,
    this.screenPayload,
    this.ensembleConfig,
    this.isPreview = false,
  }) {
    // initialize once
    GetStorage.init();
    Device().initDeviceInfo();
  }

  final ScreenPayload? screenPayload;
  final EnsembleConfig? ensembleConfig;
  final bool isPreview;

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
    GetStorage().write(previewConfig, widget.isPreview);
    config = initApp();
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    }

    notificationUtils.initNotifications();
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
            return _appPlaceholderWrapper();
          }

          return renderApp(snapshot.data as EnsembleConfig);
        }));
  }

  Widget renderApp(EnsembleConfig config) {
    //log("EnsembleApp build() - $hashCode");
    GetStorage().write(previewConfig, widget.isPreview);

    return MaterialApp(
      navigatorKey: Utils.globalAppKey,
      theme: config.getAppTheme(),
      localizationsDelegates: [
        config.getI18NDelegate(),
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
        ),
      ),
      useInheritedMediaQuery: widget.isPreview,
      locale: widget.isPreview ? DevicePreview.locale(context) : null,
      builder: widget.isPreview
          ? DevicePreview.appBuilder
          : FlutterI18n.rootAppBuilder(),
      // TODO: this case translation issue on hot loading. Address this for RTL support
      //builder: (context, widget) => FlutterI18n.rootAppBuilder().call(context, widget)
    );
  }

  /// we are at the root here. Error/Spinner widgets need
  /// to be wrapped inside MaterialApp
  Widget _appPlaceholderWrapper(
      {Widget? widget, Color? loadingBackgroundColor}) {
    return MaterialApp(
        home: Scaffold(backgroundColor: loadingBackgroundColor, body: widget));
  }
}
