import 'dart:convert';
import 'dart:io' as io;

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class WebViewState extends EWidgetState<EnsembleWebView> with CookieMethods {
  // WebView won't render on Android if height is 0 initially
  bool isCookieLoaded = false;
  io.Cookie? cookieHeader;
  double? calculatedHeight = 1;
  Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers = {};

  @override
  void initState() {
    // Unless we are in stretch mode, we want our WebView to take scrolling priority
    // when it needs to scroll, in case it is wrapped inside the rootView's scrollable.
    // In another word, when we are stretching to fit the content, there is no internal
    // scrollbar on the webview, so no need to grab the scroll gesture.
    if (widget.controller.expanded == true ||
        widget.controller.height != null) {
      gestureRecognizers = {Factory(() => EagerGestureRecognizer())};
    }
    super.initState();
    _initializeWebView();
  }

  // Initialize CookieManager once during widget creation to ensure it's ready before any
  // cookie operations and prevent multiple initializations
  Future<void> _initializeWebView() async {
    await widget.controller.initializeCookieManager();
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

  String _generateHeaderOverrideScript() {
    return '''
      const headerRules = ${jsonEncode(widget.controller.headerOverrideRules.map((r) => r.toJson()).toList())};

      function matchesRule(url, rule) {
        switch(rule.matchType) {
          case 'HeaderMatchType.CONTAINS':
            return url.includes(rule.urlPattern);
          case 'HeaderMatchType.EXACT':
            return url === rule.urlPattern;
          case 'HeaderMatchType.REGEX':
            return new RegExp(rule.urlPattern).test(url);
          default:
            return false;
        }
      }

      const originalFetch = window.fetch;
      window.fetch = async function(url, options = {}) {
        options = options || {};
        options.headers = options.headers || {};
        
        for (const rule of headerRules) {
          if (matchesRule(url, rule)) {
            
            options.headers = rule.mergeExisting 
              ? {...options.headers, ...rule.headers}
              : {...rule.headers};
              
          }
        }
          
        return originalFetch(url, options);
      };
    ''';
  }

  Future<void> setCookie(io.Cookie? cookie) async {
    if (widget.controller.url == null) {
      return;
    }
    final mainUrl = WebUri(widget.controller.url!);
    final protocol = mainUrl.scheme; // Get the actual protocol (http or https)

    if (cookie != null) {
      final cookieDomain = cookie.domain ?? mainUrl.host;

      // Set cookie for main domain
      await widget.controller.cookieManager.setCookie(
        url: WebUri('$protocol://$cookieDomain'),
        name: cookie.name,
        value: cookie.value,
        domain: cookieDomain,
        path: cookie.path ?? '/',
        isSecure: cookie.secure,
        isHttpOnly: cookie.httpOnly,
        maxAge: cookie.maxAge,
        expiresDate: cookie.expires?.millisecondsSinceEpoch,
      );
    }

    // Handle additional cookies
    if (widget.controller.cookies.isNotEmpty) {
      for (var cookieData in widget.controller.cookies) {
        final cookieDomain = cookieData['domain'] ?? mainUrl.host;

        await widget.controller.cookieManager.setCookie(
          url: WebUri('$protocol://$cookieDomain'),
          name: cookieData['name'],
          value: cookieData['value'],
          domain: cookieDomain,
          path: cookieData['path'] ?? '/',
        );
      }
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    // WebView's height will be the same as the HTML height

    Widget webViewWidget = SizedBox(
      height: widget.controller.height ?? calculatedHeight,
      width: widget.controller.width,
      child: InAppWebView(
        key: ValueKey('webview_${widget.controller.url}'),
        initialUrlRequest: widget.controller.url != null
            ? URLRequest(
                url: WebUri(widget.controller.url!),
                headers: widget.controller.headers,
              )
            : null,
        initialSettings: InAppWebViewSettings(
          // Cross Platform Settings
          useShouldOverrideUrlLoading: true,
          mediaPlaybackRequiresUserGesture: false,
          javaScriptEnabled: true,
          useOnLoadResource: true,
          transparentBackground: true,
          supportZoom: true,
          clearCache: true,
          preferredContentMode: UserPreferredContentMode.MOBILE,

          // Android Specific Settings
          useHybridComposition: true,
          hardwareAcceleration: true,
          mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
          safeBrowsingEnabled: false,
          domStorageEnabled: true,
          databaseEnabled: true,
          supportMultipleWindows: true,
          builtInZoomControls: true,
          displayZoomControls: false,
          allowFileAccess: true,
          useWideViewPort: true,
          allowContentAccess: true,
          loadWithOverviewMode: true,

          // iOS Specific Settings
          allowsInlineMediaPlayback: true,
          allowsBackForwardNavigationGestures: true,
          enableViewportScale: true,
          suppressesIncrementalRendering: false,
          allowsPictureInPictureMediaPlayback: true,
          isFraudulentWebsiteWarningEnabled: false,
        ),
        gestureRecognizers: gestureRecognizers,
        onWebViewCreated: (controller) async {
          widget.controller.webViewController = controller;
          if (cookieHeader != null) {
            await setCookie(cookieHeader);
          }
        },
        onLoadStart: (controller, url) {
          setState(() => widget.controller.loadingPercent = 0);
          if (widget.controller.onPageStart != null) {
            ScreenController().executeAction(
              context,
              widget.controller.onPageStart!,
              event: EnsembleEvent(widget, data: {'url': url.toString()}),
            );
          }
        },
        onLoadStop: (controller, url) async {
          dynamic height = await controller.evaluateJavascript(
            source: "document.documentElement.scrollHeight;",
          );
          calculatedHeight = double.parse(height.toString());

          setState(() => widget.controller.loadingPercent = 100);

          if (widget.controller.headerOverrideRules.isNotEmpty) {
            await controller.evaluateJavascript(
                source: _generateHeaderOverrideScript());
          }

          if (widget.controller.onPageFinished != null && mounted) {
            ScreenController().executeAction(
              context,
              widget.controller.onPageFinished!,
              event: EnsembleEvent(widget, data: {'url': url.toString()}),
            );
          }
        },
        onLoadError: (controller, url, code, message) {
          if (widget.controller.onWebResourceError != null) {
            ScreenController().executeAction(
              context,
              widget.controller.onWebResourceError!,
              event: EnsembleEvent(widget, data: {
                'errorCode': code,
                'description': message,
              }),
            );
          }
          setState(
              () => widget.controller.error = "Error loading html content");
        },
        onCreateWindow: (controller, createWindowAction) async {
          print('onCreateWindow: ${createWindowAction.request.url}');
          // Get the URL from the creation request
          final url = createWindowAction.request.url?.toString();
          if (url != null) {
            // Load the URL in the current WebView instead of creating a new window
            await controller.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
          }
          return true;
        },
        shouldOverrideUrlLoading: (controller, navigationAction) async {
          final url = navigationAction.request.url?.toString() ?? '';
          print('shouldOverrideUrlLoading: $url');
          // Rest of your existing navigation handling
          WebViewNavigationEvent event = WebViewNavigationEvent(widget, url);
          if (widget.controller.onNavigationRequest != null) {
            ScreenController().executeAction(
              context,
              widget.controller.onNavigationRequest!,
              event: event,
            );
          }

          if (!event.allowNavigation) {
            return NavigationActionPolicy.CANCEL;
          }

          // Check if the URL starts with any of the defined schemes
          if (widget.controller.schemes
              .any((scheme) => url.startsWith(scheme))) {
            if (await canLaunchUrl(WebUri(url))) {
              await launchUrl(WebUri(url));
              return NavigationActionPolicy.CANCEL;
            }
          }

          return NavigationActionPolicy.ALLOW;
        },
        onProgressChanged: (controller, progress) {
          setState(() => widget.controller.loadingPercent = progress);
        },
        onReceivedServerTrustAuthRequest: (controller, challenge) async {
          return ServerTrustAuthResponse(
              action: ServerTrustAuthResponseAction.PROCEED);
        },
      ),
    );

    Widget webView = FutureBuilder(
      future: setCookie(cookieHeader),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !isCookieLoaded) {
          widget.controller.webViewController?.reload();
          isCookieLoaded = true;
        }
        return webViewWidget;
      },
    );

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
            value: widget.controller.loadingPercent! / 100.0,
          ),
        ),
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
    await widget.controller.cookieManager.deleteAllCookies();
  }

  @override
  void inputCookie(String? value) {
    if (value != null) {
      cookieHeader = io.Cookie.fromSetCookieValue(value);
    }
  }
}
