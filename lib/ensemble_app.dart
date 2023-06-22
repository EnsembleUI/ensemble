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
import 'package:workmanager/workmanager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const String previewConfig = 'preview-config';
const String backgroundUploadTask = 'backgroundUploadTask';
final errorKey = GlobalKey<AppErrorHandlerState>();

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

/// use this as the root widget for Ensemble
class EnsembleApp extends StatefulWidget {
  const EnsembleApp({
    super.key,
    this.screenPayload,
    this.ensembleConfig,
    this.isPreview = false,
  });

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
    await dotenv.load();
    Device().initDeviceInfo();
    await GetStorage.init();
    GetStorage().write(previewConfig, widget.isPreview);

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
    _handleErrors();
    config = initApp();
    if (!kIsWeb) {
      Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    }

    notificationUtils.initNotifications();
  }

  void _handleErrors() {
    ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
      return const SizedBox();
    };

    FlutterError.onError = (details) {
      debugPrint(details.exception.toString());
      final state = errorKey.currentState;
      if (state != null && !state.isOverlay) {
        state.createErrorOverlay(details);
      }
    };

    // async error
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Async Error: ${error.toString()}');
      final state = errorKey.currentState;
      if (state != null && !state.isOverlay) {
        state.createErrorOverlay(error);
      }

      return true;
    };
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
      home: AppErrorHandler(
        key: errorKey,
        child: MaterialApp(
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
        ),
      ),
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

class ErrorState {
  ErrorState({
    required this.errorText,
    this.recovery,
    this.detailError,
  });

  final String errorText;
  final String? recovery;
  final String? detailError;
}

class AppErrorHandler extends StatefulWidget {
  const AppErrorHandler({super.key, required this.child});

  final Widget child;

  @override
  State<AppErrorHandler> createState() => AppErrorHandlerState();
}

class AppErrorHandlerState extends State<AppErrorHandler> {
  OverlayEntry? overlayEntry;
  bool isOverlay = false;
  late ErrorState errorState;

  void createErrorOverlay(Object error) {
    // Setup Error
    _setupError(error);
    // Remove the existing OverlayEntry.
    removeErrorOverlay();

    assert(overlayEntry == null);

    List<Widget> children = [];

    // main error and graphics
    children.add(
      Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(Utils.randomize(["Oh Snap", "Uh Oh ..", "Foo Bar"]),
              style: const TextStyle(
                  fontSize: 28,
                  color: Color(0xFFF7535A),
                  fontWeight: FontWeight.w500)),
          const Image(
              image: AssetImage("assets/images/error.png", package: 'ensemble'),
              width: 200),
          const SizedBox(height: 16),
          Text(
            errorState.errorText +
                (errorState.recovery != null ? '\n${errorState.recovery}' : ''),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );

    // add detail
    if (errorState.detailError != null) {
      children.add(
        Column(
          children: [
            const SizedBox(height: 30),
            const Text('DETAILS',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Text(errorState.detailError!,
                textAlign: TextAlign.start,
                style: const TextStyle(fontSize: 14, color: Colors.black87))
          ],
        ),
      );
    }

    overlayEntry = OverlayEntry(
      // Create a new OverlayEntry.
      builder: (BuildContext context) {
        // Align is used to position the highlight overlay
        // relative to the NavigationBar destination.
        return Scaffold(
            body: SafeArea(
                child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.only(left: 40, right: 40, top: 40),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children))));
      },
    );

    // Add the OverlayEntry to the Overlay.
    isOverlay = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      Overlay.of(context, debugRequiredFor: widget).insert(overlayEntry!);
    });
  }

  void _setupError(Object error) {
    Object myError = error;
    StackTrace? stackTrace;
    if (error is FlutterErrorDetails) {
      myError = error.exception;
      stackTrace = error.stack;
    }

    // process the error
    if (myError is EnsembleError) {
      List<String> detail = [];
      if (myError.detailError != null) {
        detail.add(myError.detailError!);
      }
      errorState = ErrorState(
        errorText: myError.error,
        recovery: myError.recovery,
        detailError: join(myError.detailError, stackTrace?.toString()),
      );
    } else if (myError is Error) {
      errorState = ErrorState(
        errorText: myError.toString(),
        detailError:
            join(myError.stackTrace?.toString(), stackTrace?.toString()),
      );
    } else {
      errorState = ErrorState(
        errorText: 'Unknown Error occurred.',
        detailError: stackTrace?.toString(),
      );
    }
  }

  static String join(String? first, String? second) {
    List<String> list = [];
    if (first != null) {
      list.add(first);
    }
    if (second != null) {
      list.add(second);
    }
    return list.join('\n');
  }

  void removeErrorOverlay() {
    isOverlay = false;
    overlayEntry?.remove();
    overlayEntry = null;
  }

  @override
  void initState() {
    super.initState();
    // WidgetsBinding.instance
    //     .addPostFrameCallback((_) => createErrorOverlay(null));
  }

  @override
  void dispose() {
    // Make sure to remove OverlayEntry when the widget is disposed.
    removeErrorOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
