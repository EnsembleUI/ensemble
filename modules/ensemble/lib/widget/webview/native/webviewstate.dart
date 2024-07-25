import 'dart:io';

import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class WebViewState extends WidgetState<EnsembleWebView> with CookieMethods {
  // WebView won't render on Android if height is 0 initially
  bool isCookieLoaded = false;
  Cookie? cookieHeader;
  double? calculatedHeight = 1;
  Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = {};
  NavigationDelegate initNavigationDelegate() {
    return NavigationDelegate(
      onProgress: (int value) {
        setState(() {
          widget.controller.loadingPercent = value;
        });
      },
      onPageStarted: (String url) {
        if (widget.controller.onPageStart != null) {
          ScreenController().executeAction(
              context, widget.controller.onPageStart!,
              event: EnsembleEvent(widget, data: {'url': url}));
        }
      },
      onPageFinished: (String url) async {
        dynamic scrollHeight = await widget.controller.webViewController!
            .runJavaScriptReturningResult(
                "document.documentElement.scrollHeight;");
        calculatedHeight = double.parse("$scrollHeight");
        setState(() {
          widget.controller.loadingPercent = 100;
        });
        if (widget.controller.onPageFinished != null) {
          if (!mounted) return;
          ScreenController().executeAction(
              context, widget.controller.onPageFinished!,
              event: EnsembleEvent(widget, data: {'url': url}));
        }
      },
      onWebResourceError: (WebResourceError error) {
        if (widget.controller.onWebResourceError != null) {
          ScreenController()
              .executeAction(context, widget.controller.onNavigationRequest!,
                  event: EnsembleEvent(widget, data: {
                    'errorCode': error.errorCode,
                    'errorType': error.errorType,
                    'description': error.description
                  }));
        }
        setState(() {
          widget.controller.error = "Error loading html content";
        });
      },
      onNavigationRequest: (NavigationRequest request) async {
        WebViewNavigationEvent event =
            WebViewNavigationEvent(widget, request.url);
        if (widget.controller.onNavigationRequest != null) {
          ScreenController().executeAction(
              context, widget.controller.onNavigationRequest!,
              event: event);
        }
        if (!event.allowNavigation) {
          return NavigationDecision.prevent;
        }
        final url = request.url;
        // Check if the URL starts with any of the defined schemes
        if (widget.controller.schemes.any((scheme) => url.startsWith(scheme))) {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url));
            return NavigationDecision.prevent;
          }
        }
        return NavigationDecision.navigate;
      },
    );
  }

  Future<void> setCookie(Cookie? cookieHeader) async {
    if (cookieHeader != null) {
      var webViewCookie = WebViewCookie(
          name: cookieHeader.name,
          value: cookieHeader.value,
          domain: cookieHeader.domain!,
          path: cookieHeader.path ?? '/');
      await widget.controller.cookieManager!.setCookie(webViewCookie);
    }
    var cookieList = widget.controller.cookies;
    for (var cookies in cookieList) {
      await widget.controller.cookieManager!.setCookie(WebViewCookie(
          name: cookies['name'],
          value: cookies["value"],
          domain: cookies["domain"],
          path: cookies['path'] ?? "/"));
    }
  }

  void initController() {
    PlatformWebViewControllerCreationParams params =
        const PlatformWebViewControllerCreationParams();
    PlatformWebViewCookieManagerCreationParams cookieParams =
        const PlatformWebViewCookieManagerCreationParams();
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      cookieParams = WebKitWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        cookieParams,
      );
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      cookieParams = AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        cookieParams,
      );
      params = AndroidWebViewControllerCreationParams
          .fromPlatformWebViewControllerCreationParams(
        params,
      );
    }

    // #docregion

    widget.controller.webViewController =
        WebViewController.fromPlatformCreationParams(params)
          ..loadRequest(Uri.parse(widget.controller.url!),
              headers: widget.controller.headers)
          ..setBackgroundColor(Colors.transparent)
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(initNavigationDelegate());
    widget.controller.cookieManager =
        WebViewCookieManager.fromPlatformCreationParams(cookieParams);
    if (widget.controller.webViewController!.platform
        is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (widget.controller.webViewController!.platform
              as AndroidWebViewController)
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
    if (widget.controller.expanded == true ||
        widget.controller.height != null) {
      gestureRecognizers = {Factory(() => EagerGestureRecognizer())};
    }
    super.initState();
  }

  @override
  void didChangeDependencies() {
    widget.controller.cookieMethods = this;
    widget.controller.cookieMethods!
        .inputCookie(widget.controller.singleCookie);
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant EnsembleWebView oldWidget) {
    widget.controller.cookieMethods = this;
    widget.controller.cookieMethods!
        .inputCookie(widget.controller.singleCookie);
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget buildWidget(BuildContext context) {
    // WebView's height will be the same as the HTML height

    Widget webViewWidget = SizedBox(
        height: widget.controller.height ?? calculatedHeight,
        width: widget.controller.width,
        child: WebViewWidget(
            controller: widget.controller.webViewController!,
            gestureRecognizers: gestureRecognizers));

    Widget webView = FutureBuilder(
        future: setCookie(cookieHeader),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              !isCookieLoaded) {
            widget.controller.webViewController!.reload();
            isCookieLoaded = true;
          }
          return webViewWidget;
        });

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        webView,
        // loading indicator
        Visibility(
            visible: widget.controller.loadingPercent! > 0 &&
                widget.controller.loadingPercent! < 100 &&
                widget.controller.error == null,
            child: LinearProgressIndicator(
                minHeight: 3,
                value: widget.controller.loadingPercent! / 100.0)),
        // error panel
        Visibility(
          visible: widget.controller.error != null,
          child: Center(child: Text(widget.controller.error ?? '')),
        ),
      ],
    );
  }

  @override
  void clearCookie() async {
    await widget.controller.cookieManager!.clearCookies();
  }

  @override
  void inputCookie(String? value) {
    if (value != null) {
      cookieHeader = Cookie.fromSetCookieValue(value);
    }
  }
}
