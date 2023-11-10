import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/webview/webviewstate.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:yaml/yaml.dart';

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
    return {"clearCookie": () => _controller.cookieMethods?.clearCookie()};
  }

  @override
  Map<String, Function> setters() {
    return {
      'headers': (value) => _controller.headers = parseYamlMap(value),
      'cookieHeader': (value) =>
          _controller.singleCookie = Utils.optionalString(value),
      'cookies': (value) => _controller.cookies = getListOfMap(value),
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

mixin CookieMethods on WidgetState<EnsembleWebView> {
  void clearCookie();
  void inputCookie(String? value);
}

class EnsembleWebViewController extends WidgetController {
  // params for each URI set
  int? loadingPercent = 0;
  String? error;

  WebViewController? webViewController;
  WebViewCookieManager? cookieManager;

  CookieMethods? cookieMethods;
  Map<String, String> headers = {};

  ensemble.EnsembleAction? onPageStart,
      onPageFinished,
      onNavigationRequest,
      onWebResourceError;

  String? _url;
  String? get url => _url;
  set url(String? url) {
    _url = url;
    error = null;
  }

  List<Map<String, dynamic>> cookies = [];
  String? singleCookie;
  double? height;
  double? width;
}

List<Map<String, dynamic>> getListOfMap(list) {
  List<Map<String, dynamic>> result = <Map<String, dynamic>>[];
  if (list is List) {
    for (var i in list) {
      Map<String, dynamic> map = Utils.getMap(i) ?? {};
      result.add(map);
    }
    return result;
  }
  return [];
}

Map<String, String> parseYamlMap(value) {
  Map<String, String> result = {};
  if (value is YamlMap) {
    YamlMap yamlMap = value;
    for (var entry in yamlMap.entries) {
      String? key = Utils.optionalString(entry.key);
      if (key != null && key.isNotEmpty) {
        result.addAll({key: Utils.getString(entry.value, fallback: "")});
      }
    }
  }
  return result;
}
