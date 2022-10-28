import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/webview/webview.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ControllerImpl extends ViewController {
  WebViewController? controller;
  ControllerImpl([this.controller]);
  @override
  void loadUrl(String url) {
    controller!.loadUrl(url);
  }
}
class WebViewState extends WidgetState<EnsembleWebView> {
  double? height = 0;
  late ControllerImpl _controller;

  @override
  void initState() {
    _controller = ControllerImpl();
    super.initState();
  }

  @override
  Widget buildWidget(BuildContext context) {
    // WebView's height will be the same as the HTML height
    Widget webView = SizedBox(
        height: height,
        child: WebView(
            initialUrl: widget.controller.uri,
            javascriptMode: JavascriptMode.unrestricted,
            onWebViewCreated:  (controller) {
              _controller.controller = controller;
              widget.controller.webViewController = _controller;
            },
            onWebResourceError: (WebResourceError err) {
              setState(() {
                widget.controller.error = "Error loading html content";
              });
            },
            onProgress: (value) {
              setState(() {
                widget.controller.loadingPercent = value;
              });
            },
            onPageFinished: (param) async {
              height = double.parse(
                  await _controller.controller!.runJavascriptReturningResult(
                      "document.documentElement.scrollHeight;"));
              setState(() {
                widget.controller.loadingPercent = 100;
              });

            })
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