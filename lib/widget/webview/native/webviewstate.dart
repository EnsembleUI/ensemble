import 'dart:developer';

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class ControllerImpl extends ViewController {
  WebViewController? controller;
  ControllerImpl([this.controller]);
  @override
  void loadUrl(String url) {
    controller!.loadRequest(Uri.parse(url));
  }
}
class WebViewState extends WidgetState<EnsembleWebView> {
  // WebView won't render on Android if height is 0 initially
  double? calculatedHeight = 1;
  late ControllerImpl _controller;
  UniqueKey key = UniqueKey();
  Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = {};
  void initController() {
    _controller = ControllerImpl();
    widget.controller.webViewController = _controller;
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
    _controller.controller = WebViewController.fromPlatformCreationParams(params)
      ..setBackgroundColor(Colors.transparent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int value) {
            setState(() {
              widget.controller.loadingPercent = value;
            });
          },

          onPageStarted: (String url) {},
          onPageFinished: (String url) async {
            calculatedHeight =
                await _controller.controller!.runJavaScriptReturningResult(
                "document.documentElement.scrollHeight;") as double;
            setState(() {
              widget.controller.loadingPercent = 100;
            });
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              widget.controller.error = "Error loading html content";
            });
          },
        ),
      );
    if ( widget.controller.url != null ) {
      _controller.controller!.loadRequest(Uri.parse(widget.controller.url!));
    }
    if (_controller.controller!.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (_controller.controller!.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion webview_controller
  }
  @override
  void initState() {
    initController();

    // Unless we are in stretch mode, we want our WebView to take scrolling priority
    // when it needs to scroll, in case it is wrapped inside the rootView's scrollable.
    // In another word, when we are stretching to fit the content, there is no internal
    // scrollbar on the webview, so no need to grab the scroll gesture.
    if (widget.controller.expanded == true || widget.controller.height != null) {
      gestureRecognizers = {
        Factory(() => EagerGestureRecognizer())
      };
    }

    super.initState();
  }

  @override
  Widget buildWidget(BuildContext context) {
    // WebView's height will be the same as the HTML height
    Widget webView = SizedBox(
        height: widget.controller.height ?? calculatedHeight,
        width: widget.controller.width,
        child: WebViewWidget(key: key,controller: _controller.controller!,gestureRecognizers:gestureRecognizers)
    );

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        webView,
        // loading indicator
        Visibility(
            visible: widget.controller.loadingPercent! > 0 && widget.controller.loadingPercent! < 100 && widget.controller.error == null,
            child: LinearProgressIndicator(
                minHeight: 3,
                value: widget.controller.loadingPercent! / 100.0
            )
        ),
        // error panel
        Visibility(
          visible: widget.controller.error != null,
          child: Center(
              child: Text(widget.controller.error ?? '')
          ),
        ),

      ],
    );

  }

}