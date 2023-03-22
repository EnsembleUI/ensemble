import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/webview/webviewstate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart' as ensemble;

class EnsembleWebView extends StatefulWidget
    with Invokable, HasController<EnsembleWebViewController, WebViewState> {
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
      'url': (value) => _controller.url = Utils.getUrl(value),
      'height': (value) => _controller.height = Utils.optionalDouble(value),
      'width': (value) => _controller.width = Utils.optionalDouble(value),
      'onPageStart': (funcDefinition) => _controller.onPageStart =
          ensemble.EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onPageFinished': (funcDefinition) => _controller.onPageFinished =
          ensemble.EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onNavigationRequest': (funcDefinition) =>
          _controller.onNavigationRequest =
              ensemble.EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onWebResourceError': (funcDefinition) => _controller.onWebResourceError =
          ensemble.EnsembleAction.fromYaml(funcDefinition, initiator: this),
      // legacy
      'uri': (value) => _controller.url = Utils.getUrl(value),
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
  ensemble.EnsembleAction? onPageStart,
      onPageFinished,
      onNavigationRequest,
      onWebResourceError;
  String? _url;
  String? get url => _url;
  set url(String? url) {
    _url = url;

    error = null;
    if (url != null) {
      webViewController?.loadUrl(url);
    }
  }

  double? height;
  double? width;
}
