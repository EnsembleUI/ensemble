import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/webview/webviewstate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
      'uri': (value) => _controller.uri = Utils.getUrl(value),
      'height': (value) => _controller.height = Utils.getDouble(value, fallback: controller.height),
      'width':(value) => _controller.width = Utils.getDouble(value, fallback: controller.height),
    };
  }
}
abstract class ViewController {
  void loadUrl(String url);
}
class EnsembleWebViewController extends WidgetController {
  // params for each URI set
  int? loadingPercent = 0;
  String? error;

  ViewController? webViewController;

  String? _uri;
  String? get uri => _uri;
  set uri(String? url) {
    _uri = url;

    error = null;
    if (url != null) {
      webViewController?.loadUrl(url);
    }
  }
  double height = 500;
  double width = 500;
}
