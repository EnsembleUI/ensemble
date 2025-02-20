import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_flutter/webview_flutter.dart';

///
///A generic library for exposing javascript widgets in Flutter webview.
///Took https://github.com/senthilnasa/high_chart as a start and genericized it
///
class JsWidget extends StatefulWidget {
  JsWidget(
      {required this.id,
      required this.createHtmlTag,
      required this.data,
      required this.scriptToInstantiate,
      required this.size,
      this.loader = const Center(child: CircularProgressIndicator()),
      this.scripts = const [],
      this.listener,
      this.preCreateScript,
      Key? key})
      : super(key: key);

  ///Custom `loader` widget, until script is loaded
  ///
  ///Has no effect on Web
  ///
  ///Defaults to `CircularProgressIndicator`
  final Widget loader;
  final String id;
  final Function scriptToInstantiate;
  final Function createHtmlTag;
  final Function? preCreateScript;
  final String data;
  Function(String msg)? listener;

  ///Widget size
  ///
  ///Height and width of the widget is required
  ///
  ///```dart
  ///Size size = Size(400, 300);
  ///```
  final Size size;

  ///Scripts to be loaded
  final List<String> scripts;
  @override
  JsWidgetState createState() => JsWidgetState();
  Function? eval;
  void evalScript(String script) {
    if (eval != null) {
      eval!(script);
    }
  }
}

class JsWidgetState extends State<JsWidget> {
  bool _isLoaded = false;
  late final WebViewController controller;
  void instantiateController() {
    PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    // #docregion webview_controller
    controller = WebViewController.fromPlatformCreationParams(params)
      ..setBackgroundColor(Colors.transparent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            _loadData();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(error.toString());
          },
          onNavigationRequest: (NavigationRequest request) async {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(getHtmlContent());
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion webview_controller
  }

  @override
  void initState() {
    super.initState();
    instantiateController();
    widget.eval = evalScript;
  }

  @override
  void dispose() {
    widget.eval = null;
    super.dispose();
  }

  void evalScript(String script) {
    controller.runJavaScript(script);
  }

  @override
  void didUpdateWidget(covariant JsWidget oldWidget) {
    if (oldWidget.data != widget.data ||
        oldWidget.size != widget.size ||
        oldWidget.scripts != widget.scripts) {
      controller.loadHtmlString(getHtmlContent());
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.size.height,
      width: widget.size.width,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          !_isLoaded ? widget.loader : const SizedBox.shrink(),
          WebViewWidget(controller: controller),
        ],
      ),
    );
  }

  String getHtmlContent() {
    String html = "";
    html +=
        '<!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=0"/> </head> <body>${widget.createHtmlTag()}';
    for (String src in widget.scripts) {
      html += '<script async="false" src="$src"></script>';
    }
    html += '</body></html>';
    return html;
  }

  void _loadData() {
    setState(() {
      _isLoaded = true;
    });
    controller.runJavaScript('''
      ${widget.scriptToInstantiate(widget.data)}
   ''');
  }
}
