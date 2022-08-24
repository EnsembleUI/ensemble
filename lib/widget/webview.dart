import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class EnsembleWebView extends StatefulWidget with Invokable, HasController<EnsembleWebViewController, WebViewState> {
  static const type = 'WebView';
  EnsembleWebView({Key? key}) : super(key: key);

  final EnsembleWebViewController _controller = EnsembleWebViewController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => WebViewState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'uri': (value) => _controller.uri = Utils.getUrl(value)
    };
  }
}

class EnsembleWebViewController extends WidgetController {
  // params for each URI set
  int? loadingPercent = 0;
  String? error;
  WebViewController? webViewController;

  String? _uri;
  set uri(String? url) {
    _uri = url;

    error = null;
    if (url != null) {
      webViewController?.loadUrl(url);
    }
  }
}

class WebViewState extends WidgetState<EnsembleWebView> {
  double? height = 0;

  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible) {
      return const SizedBox.shrink();
    }

    // WebView's height will be the same as the HTML height
    Widget webView = SizedBox(
      height: height,
      child: WebView(
        initialUrl: widget._controller._uri,
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (controller) => widget._controller.webViewController = controller,
        onWebResourceError: (WebResourceError err) {
          setState(() {
            widget._controller.error = "Error loading html content";
          });
        },
        onProgress: (value) {
          setState(() {
            widget._controller.loadingPercent = value;
          });
        },
        onPageFinished: (param) async {
          height = double.parse(
              await widget._controller.webViewController!.runJavascriptReturningResult(
                  "document.documentElement.scrollHeight;"));
          setState(() {
            widget._controller.loadingPercent = 100;
          });

      })
    );

    return Stack(
      alignment: Alignment.topLeft,
      children: [
        webView,
        // loading indicator
        Visibility(
          visible: widget._controller.loadingPercent! > 0 && widget._controller.loadingPercent! < 100 && widget._controller.error == null,
          child: LinearProgressIndicator(
            minHeight: 3,
            value: widget._controller.loadingPercent! / 100.0
          )
        ),
        // error panel
        Visibility(
          visible: widget._controller.error != null,
          child: Center(
            child: Text(widget._controller.error ?? '')
          ),
        ),

      ],
    );

  }

}