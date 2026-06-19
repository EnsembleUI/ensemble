import 'dart:html';
import 'dart:ui_web' as ui;
import 'dart:js' as js;

import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter/material.dart';

// class ControllerImpl extends ViewController {
//   final IFrameElement _iframeElement;
//   ControllerImpl(this._iframeElement);
//   @override
//   void loadUrl(String url) {
//     _iframeElement.src = url;
//   }
// }

class WebViewState extends EWidgetState<EnsembleWebView> {
  final IFrameElement _iframeElement = IFrameElement();
  HtmlElementView? htmlView;
  final String viewId =
      'iframeElement-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    htmlView = buildIFrameWidget();
    // widget.controller.webViewController = ControllerImpl(_iframeElement);
  }

  @override
  void didUpdateWidget(covariant EnsembleWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.url != widget.controller.url ||
        oldWidget.controller.html != widget.controller.html ||
        oldWidget.controller.htmlBaseUrl != widget.controller.htmlBaseUrl ||
        oldWidget.controller.injectedJavaScript !=
            widget.controller.injectedJavaScript) {
      _loadIframeContent();
    }
  }

  @override
  void dispose() {
    _cleanupIFrame();
    super.dispose();
  }

  void _cleanupIFrame() {
    _iframeElement.src = 'about:blank';
    _iframeElement.remove();
    htmlView = null;
  }

  HtmlElementView buildIFrameWidget() {
    _iframeElement.style.width = '100%';
    _iframeElement.style.height = '100%';
    _iframeElement.style.border = 'none';

    _loadIframeContent();
    _setupJavaScriptChannels();

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      viewId,
      (int viewId) => _iframeElement,
    );

    return HtmlElementView(
      key: UniqueKey(),
      viewType: viewId,
    );
  }

  void _loadIframeContent() {
    final html = widget.controller.html;
    if (html != null && html.isNotEmpty) {
      _iframeElement.removeAttribute('src');
      _iframeElement.srcdoc = buildIframeHtmlDocument(
        html: html,
        htmlBaseUrl: widget.controller.htmlBaseUrl,
        injectedJavaScript: widget.controller.injectedJavaScript,
      );
      return;
    }

    _iframeElement.removeAttribute('srcdoc');
    _iframeElement.src = widget.controller.url ?? '';
  }

  void _setupJavaScriptChannels() {
    window.addEventListener('message', (event) {
      if (event is MessageEvent) {
        _handleWebMessage(event);
      }
    });
  }

  void _handleWebMessage(MessageEvent event) {
    final expectedOrigin = resolvedWebViewOrigin(
      url: widget.controller.url,
      htmlBaseUrl: widget.controller.htmlBaseUrl,
    );
    if (expectedOrigin != null &&
        expectedOrigin.isNotEmpty &&
        event.origin != expectedOrigin) {
      return;
    }

    // Parse the message data
    Map<String, dynamic>? messageData;
    try {
      if (event.data is String) {
        messageData = js.context['JSON'].callMethod('parse', [event.data]);
      } else if (event.data is Map) {
        messageData = Map<String, dynamic>.from(event.data);
      }
    } catch (e) {
      // If parsing fails, treat as simple string message
      messageData = {'message': event.data};
    }

    // Find the appropriate channel and execute the action
    for (var channel in widget.controller.javascriptChannels) {
      if (messageData?['channel'] == channel.name) {
        if (channel.onMessageReceived != null) {
          ScreenController().executeAction(
            context,
            channel.onMessageReceived!,
            event: EnsembleEvent(widget, data: {
              'message': messageData?['message'],
              'channel': channel.name,
            }),
          );
        }
      }
    }
  }

  bool get _hasContent =>
      (widget.controller.url != null && widget.controller.url!.isNotEmpty) ||
      (widget.controller.html != null && widget.controller.html!.isNotEmpty);

  @override
  Widget buildWidget(BuildContext context) {
    // WebView's height will be the same as the HTML height
    if (!_hasContent) {
      return const Text('Loading...');
    }
    return SizedBox(height: widget.controller.height, child: htmlView!);
  }
}
