import 'dart:html';
import 'dart:ui' as ui;

import 'package:ensemble/framework/widget/widget.dart';
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
  final String viewId = 'iframeElement-${DateTime.now().millisecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    htmlView = buildIFrameWidget();
    // widget.controller.webViewController = ControllerImpl(_iframeElement);
  }

  HtmlElementView buildIFrameWidget() {
    _iframeElement.style.width = '100%';
    _iframeElement.style.height = '100%';

    _iframeElement.src = widget.controller.url ?? '';
    _iframeElement.style.border = 'none';

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

  @override
  Widget buildWidget(BuildContext context) {
    // WebView's height will be the same as the HTML height
    if (widget.controller.url == null) {
      return const Text('Loading...');
    }
    return SizedBox(height: widget.controller.height, child: htmlView!);
  }
}
